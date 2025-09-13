unit rAsapAudioPlayer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, libAsapStatic, libraudio,
  rAudioIntf, contnrs, syncobjs, math;

type
  { TAsapAudioPlayer }
  TAsapAudioPlayer = class(TInterfacedObject, IMusicPlayer)
  private
    FStream: TAudioStream;
    FFilename: string;
    FFileData: Pointer;
    FFileSize: NativeUInt;
    FAsap: PASAP;
    FAsapInfo: PASAPInfo;
    FIsPaused: Boolean;
    FLoopMode: Boolean;
    FCurrentTrack: Integer;
    FPositionLock: TCriticalSection;
    FTrackEndTriggered: Boolean;

    FEqBands: TEqBands;
    FEqBandsDecay: TEqBandsDecay;

    // Event handlers
    FOnPlay: TPlayEvent;
    FOnPause: TPauseEvent;
    FOnStop: TStopEvent;
    FOnEnd: TEndEvent;
    FOnError: TErrorEvent;

    class var FPlayers: TFPHashList;
    class var FCurrentPlayer: TAsapAudioPlayer;

    class constructor ClassCreate;
    class destructor ClassDestroy;

    procedure InitializeAudioStream;
    procedure ResetPlayback;
    class procedure AudioCallback(bufferData: pointer; frames: LongWord); static; cdecl;
    procedure InternalStop(ClearAsap: Boolean = True);
    procedure CheckError(Condition: Boolean; const Msg: string);
    procedure LoadModuleFile(const MusicFile: string);
    procedure FreeModuleData;

    procedure AnalyzeAudioBuffer(buffer: PByte; size: Integer);

    const
      DEFAULT_FREQ = 44100;
      DEFAULT_BITS = 16;
      DEFAULT_CHANNELS = 1;
      BUFFER_SIZE = 4096; // Размер буфера для рендеринга звука

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

{ TAsapAudioPlayer }

class constructor TAsapAudioPlayer.ClassCreate;
begin
  FPlayers := TFPHashList.Create;
  FCurrentPlayer := nil;
end;

class destructor TAsapAudioPlayer.ClassDestroy;
begin
  FPlayers.Free;
end;

constructor TAsapAudioPlayer.Create;
var
  i: integer;
begin
  inherited Create;
  FTrackEndTriggered := False;
  FIsPaused := False;
  FLoopMode := False;
  FCurrentTrack := 0;
  FPositionLock := TCriticalSection.Create;
  FFileData := nil;
  FFileSize := 0;
  FAsap := nil;
  FAsapInfo := nil;

  for i := 0 to EQ_BANDS - 1 do
  begin
    FEqBands[i] := 0;
    FEqBandsDecay[i] := 0;
  end;

  InitializeAudioStream;
end;

destructor TAsapAudioPlayer.Destroy;
begin
  InternalStop;
  FreeModuleData;
  FPositionLock.Free;
  inherited Destroy;
end;

procedure TAsapAudioPlayer.InitializeAudioStream;
begin
  SetAudioStreamBufferSizeDefault(BUFFER_SIZE);
  FStream := LoadAudioStream(DEFAULT_FREQ, DEFAULT_BITS, DEFAULT_CHANNELS);
  if not IsAudioStreamReady(FStream) then
    raise Exception.Create('Failed to initialize audio stream');

  FPlayers.Add(IntToStr(PtrInt(Self)), Self);
  SetAudioStreamCallback(FStream, @AudioCallback);
end;

procedure TAsapAudioPlayer.LoadModuleFile(const MusicFile: string);
var
  FileStream: TFileStream;
begin
  FreeModuleData;

  try
    FileStream := TFileStream.Create(MusicFile, fmOpenRead or fmShareDenyWrite);
    try
      FFileSize := FileStream.Size;
      GetMem(FFileData, FFileSize);
      FileStream.ReadBuffer(FFileData^, FFileSize);
    finally
      FileStream.Free;
    end;

    // Инициализация ASAP
    FAsap := ASAP_New;
    if FAsap = nil then
      raise Exception.Create('Failed to create ASAP instance');

    // Загрузка модуля
    if not ASAP_Load(FAsap, PChar(MusicFile), FFileData, FFileSize) then
      raise Exception.Create('Failed to load ASAP module');

    // Получение информации о модуле
    FAsapInfo := ASAP_GetInfo(FAsap);
    if FAsapInfo = nil then
      raise Exception.Create('Failed to get ASAP module info');

   // ASAPInfo_SetNtsc(FAsap,false);  // PAL/NTSC
        // Установка частоты дискретизации
    ASAP_SetSampleRate(FAsap, DEFAULT_FREQ);

    // Воспроизведение выбранного трека
    if not ASAP_PlaySong(FAsap, FCurrentTrack, -1) then
      raise Exception.Create('Failed to play ASAP song');

    FFilename := MusicFile;
  except
    FreeModuleData;
    raise;
  end;
end;

procedure TAsapAudioPlayer.FreeModuleData;
begin
  if FAsapInfo <> nil then
  begin
   // ASAPInfo_Delete(FAsapInfo);
    FAsapInfo := nil;
  end;

  if FAsap <> nil then
  begin
    ASAP_Delete(FAsap);
    FAsap := nil;
  end;

  if FFileData <> nil then
  begin
    FreeMem(FFileData);
    FFileData := nil;
    FFileSize := 0;
  end;
end;

procedure TAsapAudioPlayer.AnalyzeAudioBuffer(buffer: PByte; size: Integer);
{$I BandAnalyzer.inc}
end;

procedure TAsapAudioPlayer.ResetPlayback;
begin
  if FAsap <> nil then
  begin
    // Сброс позиции воспроизведения
    ASAP_Seek(FAsap, 0);
  end;
end;

class procedure TAsapAudioPlayer.AudioCallback(bufferData: pointer; frames: LongWord); cdecl;
var
  SamplesRendered: Integer;
begin
  if FCurrentPlayer = nil then Exit;

  with FCurrentPlayer do
  begin
    FPositionLock.Enter;
    try
      if (FAsap = nil) or FIsPaused then
      begin
       // FillChar(bufferData^, frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8), 0);
       // Exit;
      end;

      // Рендерим звук в буфер
      SamplesRendered := ASAP_Generate(
        FAsap,
        bufferData,
        frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8) ,
        ASAPSampleFormat_S16_L_E
      );


 //     NumSmp := BufSize div (NumChan * (BitsPerSample div 16));
//      Gensmp := ASAP_Generate(asap_instance, @Form1.buffers[bufferIndex][0], NumSmp,ASAPSampleFormat.ASAPSampleFormat_S16_L_E) div 2  ;  // _U8
      ASAPInfo_SetNtsc(FAsap, false);


      // TTF анализ
      AnalyzeAudioBuffer(bufferData, frames);

      // Проверка окончания трека
      if GetPosition >= GetDuration then
      begin
        if Assigned(FOnEnd) and (not FLoopMode) then
        begin
          FOnEnd(FCurrentPlayer, FCurrentTrack, true);
          FTrackEndTriggered := True;
        end;

        if FLoopMode then
        begin
          ResetPlayback;
          FTrackEndTriggered := False;
        end;
      end;

    finally
      FPositionLock.Leave;
      if FTrackEndTriggered then
        InternalStop(True);
    end;
  end;
end;

procedure TAsapAudioPlayer.CheckError(Condition: Boolean; const Msg: string);
begin
  if Condition and Assigned(FOnError) then
    FOnError(Self, Msg);
end;

procedure TAsapAudioPlayer.InternalStop(ClearAsap: Boolean);
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

      if ClearAsap then
        FreeModuleData;

      FIsPaused := False;
      FTrackEndTriggered := False;

      if Assigned(FOnStop) then
        FOnStop(Self, FCurrentTrack);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TAsapAudioPlayer.Play(const MusicFile: String; Track: Integer);
begin
  if not FileExists(MusicFile) then
  begin
    CheckError(True, 'File not found: ' + MusicFile);
    Exit;
  end;

  FPositionLock.Enter;
  try
    // Останавливаем текущее воспроизведение
    if IsAudioStreamPlaying(FStream) then
      InternalStop;

    // Загружаем новый модуль
    try
      FCurrentTrack := Track;
      LoadModuleFile(MusicFile);

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
        CheckError(True, 'Error loading module: ' + E.Message);
        InternalStop;
      end;
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TAsapAudioPlayer.Pause;
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

procedure TAsapAudioPlayer.Resume;
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

procedure TAsapAudioPlayer.Stop;
begin
  InternalStop;
end;

procedure TAsapAudioPlayer.SetPosition(PositionMs: Integer);
var
  SamplePos: Integer;
begin
  FPositionLock.Enter;
  try
    if FAsap <> nil then
    begin
      SamplePos := (PositionMs * DEFAULT_FREQ) div 1000;
      ASAP_SeekSample(FAsap, SamplePos);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TAsapAudioPlayer.GetPosition: Integer;
var
  Position: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if FAsap <> nil then
    begin
      Position := ASAP_GetPosition(FAsap);
      Result := (Position * 1000) div DEFAULT_FREQ;
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TAsapAudioPlayer.GetDuration: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if (FAsapInfo <> nil) and (FCurrentTrack >= 0) then
    begin
      Result := ASAPInfo_GetDuration(FAsapInfo, FCurrentTrack);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TAsapAudioPlayer.SetLoopMode(Mode: Boolean);
begin
  FLoopMode := Mode;
  // ASAP автоматически обрабатывает зацикливание через ASAPInfo_GetLoop
end;

function TAsapAudioPlayer.GetLoopMode: Boolean;
begin
  Result := FLoopMode;
  if (FAsapInfo <> nil) and (FCurrentTrack >= 0) then
  begin
    Result := Result or ASAPInfo_GetLoop(FAsapInfo, FCurrentTrack);
  end;
end;

function TAsapAudioPlayer.IsPlaying: Boolean;
begin
  Result := (FCurrentPlayer = Self) and not FIsPaused and (FAsap <> nil);
end;

function TAsapAudioPlayer.IsPaused: Boolean;
begin
  Result := FIsPaused;
end;

function TAsapAudioPlayer.GetCurrentTrack: Integer;
begin
  Result := FCurrentTrack;
end;

function TAsapAudioPlayer.GetCurrentFile: String;
begin
  Result := FFilename;
end;

function TAsapAudioPlayer.GetTrackCount: Integer;
begin
  Result := 1;
  if FAsapInfo <> nil then
  begin
    Result := ASAPInfo_GetSongs(FAsapInfo);
  end;
end;

function TAsapAudioPlayer.GetEQBandsDecay: TEqBandsDecay;
begin
  Result := FEqBandsDecay;
end;

// Event property getters/setters
function TAsapAudioPlayer.GetOnPlay: TPlayEvent;
begin
  Result := FOnPlay;
end;

function TAsapAudioPlayer.GetOnPause: TPauseEvent;
begin
  Result := FOnPause;
end;

function TAsapAudioPlayer.GetOnStop: TStopEvent;
begin
  Result := FOnStop;
end;

function TAsapAudioPlayer.GetOnEnd: TEndEvent;
begin
  Result := FOnEnd;
end;

function TAsapAudioPlayer.GetOnError: TErrorEvent;
begin
  Result := FOnError;
end;

procedure TAsapAudioPlayer.SetOnPlay(AEvent: TPlayEvent);
begin
  FOnPlay := AEvent;
end;

procedure TAsapAudioPlayer.SetOnPause(AEvent: TPauseEvent);
begin
  FOnPause := AEvent;
end;

procedure TAsapAudioPlayer.SetOnStop(AEvent: TStopEvent);
begin
  FOnStop := AEvent;
end;

procedure TAsapAudioPlayer.SetOnEnd(AEvent: TEndEvent);
begin
  FOnEnd := AEvent;
end;

procedure TAsapAudioPlayer.SetOnError(AEvent: TErrorEvent);
begin
  FOnError := AEvent;
end;

end.
