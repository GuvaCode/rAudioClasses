unit rVgmAudioPlayer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, libvgmplay, libraudio, CommonTypes,
  rAudioIntf, contnrs, syncobjs, math;

type
  { TVgmAudioPlayer }
  TVgmAudioPlayer = class(TInterfacedObject, IMusicPlayer)
  private
    FStream: TAudioStream;
    FFilename: string;
    FIsPaused: Boolean;
    FLoopMode: Boolean;
    FCurrentTrack: Integer;
    FTrackCount: Integer;
    FPositionLock: TCriticalSection;
    FTrackEndTriggered: Boolean;
    FVGMHeader: VGM_HEADER;
    FVGMTag: VGM_TAG;

    FEqBands: TEqBands;
    FEqBandsDecay: TEqBandsDecay;

    // Event handlers
    FOnPlay: TPlayEvent;
    FOnPause: TPauseEvent;
    FOnStop: TStopEvent;
    FOnEnd: TEndEvent;
    FOnError: TErrorEvent;

    class var FPlayers: TFPHashList;
    class var FCurrentPlayer: TVgmAudioPlayer;

    class constructor ClassCreate;
    class destructor ClassDestroy;

    procedure InitializeAudioStream;
    procedure ResetPlayback;
    class procedure AudioCallback(bufferData: pointer; frames: LongWord); static; cdecl;
    procedure InternalStop(ClearData: Boolean = True);
    procedure CheckError(Condition: Boolean; const Msg: string);
    procedure LoadVGMFile(const MusicFile: string);
    procedure FreeVGMData;
    procedure AnalyzeAudioBuffer(buffer: PByte; size: Integer);
    function GetCurrentTrackDuration: Integer;

    const
      DEFAULT_FREQ = 44100;
      DEFAULT_BITS = 16;
      DEFAULT_CHANNELS = 2;
      BUFFER_SIZE = 8192;

  public
    constructor Create;
    destructor Destroy; override;

    // IMusicPlayer implementation
    procedure Play(const MusicFile: String; Track: Integer = 0);
    procedure Pause;
    procedure Resume;
    procedure Stop;
    procedure SetPosition(PositionMs: Integer);
    function GetPosition: Integer;
    function GetDuration: Integer;
    procedure SetLoopMode(Mode: Boolean);
    function GetLoopMode: Boolean;
    function IsPlaying: Boolean;
    function IsPaused: Boolean;
    function GetCurrentTrack: Integer;
    function GetCurrentFile: String;
    function GetTrackCount: Integer;

    // Вывод TTF
    function GetEQBandsDecay: TEqBandsDecay;

    // Event properties
    function GetOnPlay: TPlayEvent;
    function GetOnPause: TPauseEvent;
    function GetOnStop: TStopEvent;
    function GetOnEnd: TEndEvent;
    function GetOnError: TErrorEvent;
    procedure SetOnPlay(AEvent: TPlayEvent);
    procedure SetOnPause(AEvent: TPauseEvent);
    procedure SetOnStop(AEvent: TStopEvent);
    procedure SetOnEnd(AEvent: TEndEvent);
    procedure SetOnError(AEvent: TErrorEvent);

    property OnPlay: TPlayEvent read GetOnPlay write SetOnPlay;
    property OnPause: TPauseEvent read GetOnPause write SetOnPause;
    property OnStop: TStopEvent read GetOnStop write SetOnStop;
    property OnEnd: TEndEvent read GetOnEnd write SetOnEnd;
    property OnError: TErrorEvent read GetOnError write SetOnError;
  end;

implementation

{ TVgmAudioPlayer }

class constructor TVgmAudioPlayer.ClassCreate;
begin
  FPlayers := TFPHashList.Create;
  FCurrentPlayer := nil;

  // Загружаем библиотеку VGMPlay при первом создании плеера
  if not VGMLoaded then
    LoadVGMLibrary;
end;

class destructor TVgmAudioPlayer.ClassDestroy;
begin
  FPlayers.Free;
end;

constructor TVgmAudioPlayer.Create;
var
  i: Integer;
begin
  inherited Create;
  FTrackEndTriggered := False;
  FIsPaused := False;
  FLoopMode := False;
  FCurrentTrack := 0;
  FTrackCount := 1; // VGM файлы обычно содержат один трек
  FPositionLock := TCriticalSection.Create;

  // Инициализируем структуры VGM
  FillChar(FVGMHeader, SizeOf(VGM_HEADER), 0);
  FillChar(FVGMTag, SizeOf(VGM_TAG), 0);

  for i := 0 to EQ_BANDS - 1 do
  begin
    FEqBands[i] := 0;
    FEqBandsDecay[i] := 0;
  end;

  InitializeAudioStream;
end;

destructor TVgmAudioPlayer.Destroy;
begin
  InternalStop;
  FreeVGMData;
  FPositionLock.Free;
  inherited Destroy;
end;

procedure TVgmAudioPlayer.InitializeAudioStream;
begin
  SetAudioStreamBufferSizeDefault(BUFFER_SIZE);
  FStream := LoadAudioStream(DEFAULT_FREQ, DEFAULT_BITS, DEFAULT_CHANNELS);
  if not IsAudioStreamReady(FStream) then
    raise Exception.Create('Failed to initialize audio stream');

  FPlayers.Add(IntToStr(PtrInt(Self)), Self);
  SetAudioStreamCallback(FStream, @AudioCallback);
end;

procedure TVgmAudioPlayer.LoadVGMFile(const MusicFile: string);
var
  FileNameW: WideString;
  ResultCode: Integer;
begin
  FreeVGMData;

  try
    // Проверяем, загружена ли библиотека VGMPlay
    if not VGMLoaded then
      raise Exception.Create('VGMPlay library not loaded');

    // Открываем VGM файл
    FileNameW := UTF8Decode(MusicFile);
    if not OpenVGMFileW(PWideChar(FileNameW)) then
      raise Exception.Create('Failed to open VGM file');

    // Получаем информацию о файле
    ResultCode := GetVGMFileInfoW(PWideChar(FileNameW), @FVGMHeader, FVGMTag);
    if ResultCode = 0 then
      raise Exception.Create('Failed to get VGM file info');

    // Инициализируем воспроизведение
    VGMPlay_Init;

    // Устанавливаем режим зацикливания
    if FLoopMode then
      RefreshPlaybackOptions; // VGMPlay автоматически обрабатывает зацикливание

    FFilename := MusicFile;
  except
    FreeVGMData;
    raise;
  end;
end;

procedure TVgmAudioPlayer.FreeVGMData;
begin
  if VGMLoaded then
  begin
    StopVGM;
    CloseVGMFile;
    VGMPlay_Deinit;

    // Освобождаем GD3 тег, если он был выделен
    if FVGMTag.fccGD3 = FCC_GD3 then
      FreeGD3Tag(@FVGMTag);
  end;

  FillChar(FVGMHeader, SizeOf(VGM_HEADER), 0);
  FillChar(FVGMTag, SizeOf(VGM_TAG), 0);
  FTrackCount := 1;
end;

function TVgmAudioPlayer.GetCurrentTrackDuration: Integer;
begin
  Result := 0;

  if FVGMHeader.fccVGM = FCC_VGM then
  begin
    // Преобразуем количество сэмплов в миллисекунды
    if FVGMHeader.lngRate > 0 then
      Result := Round((FVGMHeader.lngTotalSamples / FVGMHeader.lngRate) * 1000)
    else if FVGMHeader.lngHzPSG > 0 then
      Result := Round((FVGMHeader.lngTotalSamples / FVGMHeader.lngHzPSG) * 1000)
    else
      Result := 180000; // 3 минуты по умолчанию
  end
  else
  begin
    Result := 180000; // 3 минуты по умолчанию
  end;
end;

procedure TVgmAudioPlayer.AnalyzeAudioBuffer(buffer: PByte; size: Integer);
{$I BandAnalyzer.inc}
end;

procedure TVgmAudioPlayer.ResetPlayback;
begin
  if VGMLoaded then
  begin
    SeekVGM(False, 0); // Перемещаемся в начало
  end;
end;

class procedure TVgmAudioPlayer.AudioCallback(bufferData: pointer; frames: LongWord); cdecl;
var
  BytesRendered: Integer;
begin
  if FCurrentPlayer = nil then Exit;

  with FCurrentPlayer do
  begin
    FPositionLock.Enter;
    try
      if not VGMLoaded or FIsPaused then
      begin
        FillChar(bufferData^, frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8), 0);
        Exit;
      end;

      // Рендерим аудио через VGMPlay
      BytesRendered := FillBuffer(bufferData, frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8));

      if BytesRendered <= 0 then
      begin
        // Конец трека или ошибка
        if Assigned(FOnEnd) and (not FLoopMode) then
        begin
          FOnEnd(FCurrentPlayer, FCurrentTrack, True);
          FTrackEndTriggered := True;
        end;

        if FLoopMode then
        begin
          ResetPlayback;
          FTrackEndTriggered := False;
        end
        else
        begin
          FillChar(bufferData^, frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8), 0);
        end;
      end
      else
      begin
        // TTF analysis только если есть данные
        AnalyzeAudioBuffer(bufferData, BytesRendered);
      end;
    finally
      FPositionLock.Leave;
      if FTrackEndTriggered then InternalStop(True);
    end;
  end;
end;

procedure TVgmAudioPlayer.CheckError(Condition: Boolean; const Msg: string);
begin
  if Condition and Assigned(FOnError) then
    FOnError(Self, Msg);
end;

procedure TVgmAudioPlayer.InternalStop(ClearData: Boolean);
begin
  FPositionLock.Enter;
  try
    if (FCurrentPlayer = Self) and IsAudioStreamPlaying(FStream) then
    begin
      if FCurrentPlayer = Self then
      begin
        StopAudioStream(FStream);
        FCurrentPlayer := nil;
      end;

      if ClearData then
        FreeVGMData;

      FIsPaused := False;
      FTrackEndTriggered := False;

      if Assigned(FOnStop) then
        FOnStop(Self, FCurrentTrack);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TVgmAudioPlayer.Play(const MusicFile: String; Track: Integer);
begin
  if not FileExists(MusicFile) then
  begin
    CheckError(True, 'File not found: ' + MusicFile);
    Exit;
  end;

  FPositionLock.Enter;
  try
    // Останавливаем текущее воспроизведение
    if IsAudioStreamPlaying(FStream) then InternalStop;

    // Загружаем новый VGM файл
    try
      FCurrentTrack := Track;
      LoadVGMFile(MusicFile);

      // Начинаем воспроизведение
      FCurrentPlayer := Self;
      PlayAudioStream(FStream);
      FIsPaused := False;
      FTrackEndTriggered := False;

      if Assigned(FOnPlay) then
        FOnPlay(Self, FCurrentTrack);
    except
      on E: Exception do
      begin
        CheckError(True, 'Error loading VGM file: ' + E.Message);
        InternalStop;
      end;
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TVgmAudioPlayer.Pause;
begin
  FPositionLock.Enter;
  try
    if (FCurrentPlayer = Self) and not FIsPaused then
    begin
      PauseAudioStream(FStream);
      FIsPaused := True;

      if Assigned(FOnPause) then
        FOnPause(Self, FCurrentTrack);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TVgmAudioPlayer.Resume;
begin
  FPositionLock.Enter;
  try
    if (FCurrentPlayer = Self) and FIsPaused then
    begin
      ResumeAudioStream(FStream);
      FIsPaused := False;

      if Assigned(FOnPlay) then
        FOnPlay(Self, FCurrentTrack);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TVgmAudioPlayer.Stop;
begin
  InternalStop;
end;

procedure TVgmAudioPlayer.SetPosition(PositionMs: Integer);
var
  Samples: Int32;
begin
  FPositionLock.Enter;
  try
    if VGMLoaded then
    begin
      // Преобразуем миллисекунды в сэмплы
      if FVGMHeader.lngRate > 0 then
        Samples := Round((PositionMs / 1000) * FVGMHeader.lngRate)
      else if FVGMHeader.lngHzPSG > 0 then
        Samples := Round((PositionMs / 1000) * FVGMHeader.lngHzPSG)
      else
        Samples := Round((PositionMs / 1000) * 44100); // По умолчанию 44.1 kHz

      SeekVGM(False, Samples);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TVgmAudioPlayer.GetPosition: Integer;
var
  Samples: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if VGMLoaded and (FVGMHeader.lngRate > 0) then
    begin
      // Здесь нужно получить текущую позицию в сэмплах из VGMPlay
      // Это упрощенная реализация - в реальности нужно использовать
      // внутренние функции VGMPlay для получения позиции
      Samples := 0; // Заглушка - нужно реализовать получение позиции
      Result := Round((Samples / FVGMHeader.lngRate) * 1000);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TVgmAudioPlayer.GetDuration: Integer;
begin
  Result := GetCurrentTrackDuration;
end;

procedure TVgmAudioPlayer.SetLoopMode(Mode: Boolean);
begin
  FLoopMode := Mode;
  FPositionLock.Enter;
  try
    if VGMLoaded then
    begin
      RefreshPlaybackOptions; // Обновляем настройки воспроизведения
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TVgmAudioPlayer.GetLoopMode: Boolean;
begin
  Result := FLoopMode;
end;

function TVgmAudioPlayer.IsPlaying: Boolean;
begin
  Result := (FCurrentPlayer = Self) and not FIsPaused and VGMLoaded;
end;

function TVgmAudioPlayer.IsPaused: Boolean;
begin
  Result := FIsPaused;
end;

function TVgmAudioPlayer.GetCurrentTrack: Integer;
begin
  Result := FCurrentTrack;
end;

function TVgmAudioPlayer.GetCurrentFile: String;
begin
  Result := FFilename;
end;

function TVgmAudioPlayer.GetTrackCount: Integer;
begin
  Result := FTrackCount; // VGM файлы обычно содержат 1 трек
end;

function TVgmAudioPlayer.GetEQBandsDecay: TEqBandsDecay;
begin
  Result := FEqBandsDecay;
end;

// Event property getters/setters
function TVgmAudioPlayer.GetOnPlay: TPlayEvent;
begin
  Result := FOnPlay;
end;

function TVgmAudioPlayer.GetOnPause: TPauseEvent;
begin
  Result := FOnPause;
end;

function TVgmAudioPlayer.GetOnStop: TStopEvent;
begin
  Result := FOnStop;
end;

function TVgmAudioPlayer.GetOnEnd: TEndEvent;
begin
  Result := FOnEnd;
end;

function TVgmAudioPlayer.GetOnError: TErrorEvent;
begin
  Result := FOnError;
end;

procedure TVgmAudioPlayer.SetOnPlay(AEvent: TPlayEvent);
begin
  FOnPlay := AEvent;
end;

procedure TVgmAudioPlayer.SetOnPause(AEvent: TPauseEvent);
begin
  FOnPause := AEvent;
end;

procedure TVgmAudioPlayer.SetOnStop(AEvent: TStopEvent);
begin
  FOnStop := AEvent;
end;

procedure TVgmAudioPlayer.SetOnEnd(AEvent: TEndEvent);
begin
  FOnEnd := AEvent;
end;

procedure TVgmAudioPlayer.SetOnError(AEvent: TErrorEvent);
begin
  FOnError := AEvent;
end;

end.
