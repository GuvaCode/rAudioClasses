unit rXmpAudioPlayer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, libxmp, libraudio, CommonTypes,
  rAudioIntf, contnrs, syncobjs, math;

type
  { TXmpAudioPlayer }
  TXmpAudioPlayer = class(TInterfacedObject, IMusicPlayer)
  private
    FStream: TAudioStream;
    FFilename: string;
    FXmpContext: xmp_context;
    FIsPaused: Boolean;
    FLoopMode: Boolean;
    FCurrentTrack: Integer;
    FPositionLock: TCriticalSection;
    FTrackEndTriggered: Boolean;
    FFrameInfo: xmp_frame_info;
    FModuleInfo: xmp_module_info;

    FEqBands: TEqBands;
    FEqBandsDecay: TEqBandsDecay;

    // Event handlers
    FOnPlay: TPlayEvent;
    FOnPause: TPauseEvent;
    FOnStop: TStopEvent;
    FOnEnd: TEndEvent;
    FOnError: TErrorEvent;

    class var FPlayers: TFPHashList;
    class var FCurrentPlayer: TXmpAudioPlayer;

    class constructor ClassCreate;
    class destructor ClassDestroy;

    procedure InitializeAudioStream;
    procedure ResetPlayback;
    class procedure AudioCallback(bufferData: pointer; frames: LongWord); static; cdecl;
    procedure InternalStop(ClearModule: Boolean = True);
    procedure CheckError(Condition: Boolean; const Msg: string);
    procedure LoadModuleFile(const MusicFile: string);
    procedure FreeModuleData;
    procedure AnalyzeAudioBuffer(buffer: PByte; size: Integer);

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

{ TXmpAudioPlayer }

class constructor TXmpAudioPlayer.ClassCreate;
begin
  FPlayers := TFPHashList.Create;
  FCurrentPlayer := nil;
end;

class destructor TXmpAudioPlayer.ClassDestroy;
begin
  FPlayers.Free;
end;

constructor TXmpAudioPlayer.Create;
var
  i: integer;
begin
  inherited Create;
  FTrackEndTriggered := False;
  FIsPaused := False;
  FLoopMode := False;
  FCurrentTrack := 0;
  FPositionLock := TCriticalSection.Create;
  FXmpContext := nil;

  for i := 0 to EQ_BANDS - 1 do
  begin
    FEqBands[i] := 0;
    FEqBandsDecay[i] := 0;
  end;



  FXmpContext := xmp_create_context();
  if FXmpContext = nil then
    raise Exception.Create('Failed to create XMP context');

  InitializeAudioStream;
end;

destructor TXmpAudioPlayer.Destroy;
begin
  InternalStop;
  FreeModuleData;
  FPositionLock.Free;

  if FXmpContext <> nil then
  begin
    xmp_free_context(FXmpContext);
    FXmpContext := nil;
  end;


  inherited Destroy;
end;

procedure TXmpAudioPlayer.InitializeAudioStream;
begin
  SetAudioStreamBufferSizeDefault(BUFFER_SIZE);

  FStream := LoadAudioStream(DEFAULT_FREQ, DEFAULT_BITS, DEFAULT_CHANNELS);

  if not IsAudioStreamReady(FStream) then
    raise Exception.Create('Failed to initialize audio stream');

  FPlayers.Add(IntToStr(PtrInt(Self)), Self);

  SetAudioStreamCallback(FStream, @AudioCallback);
end;

procedure TXmpAudioPlayer.LoadModuleFile(const MusicFile: string);
var
  Error: Integer;
begin
  FreeModuleData;

  try
    // Загружаем модуль из файла
    Error := xmp_load_module(FXmpContext, PChar(MusicFile));
    if Error <> 0 then
      raise Exception.Create('Failed to load XMP module: Error ' + IntToStr(Error));

    // Запускаем плеер
    Error := xmp_start_player(FXmpContext, DEFAULT_FREQ, 0);

    if Error <> 0 then
      raise Exception.Create('Failed to start XMP player: Error ' + IntToStr(Error));

    // Получаем информацию о модуле
    xmp_get_module_info(FXmpContext, FModuleInfo);
    xmp_get_frame_info(FXmpContext, FFrameInfo);

    FFilename := MusicFile;
  except
    FreeModuleData;
    raise;
  end;
end;

procedure TXmpAudioPlayer.FreeModuleData;
begin
  if FXmpContext <> nil then
  begin
    xmp_stop_module(FXmpContext);
    xmp_end_player(FXmpContext);
    xmp_release_module(FXmpContext);
  end;
end;

procedure TXmpAudioPlayer.AnalyzeAudioBuffer(buffer: PByte; size: Integer);
var
  i, j, SampleCount: Integer;
  Sample: SmallInt;
  ChannelCount: Integer;
  SampleValue, Energy: Double;
  BandFactors: array[0..5] of Double = (0.1, 0.3, 0.5, 0.7, 0.9, 1.1);
begin
  if size = 0 then Exit;

  ChannelCount := DEFAULT_CHANNELS;
  SampleCount := size div (DEFAULT_BITS div 8) div ChannelCount;

  if SampleCount = 0 then Exit;

  // Анализируем каждый 10-й семпл для производительности
  for i := 0 to SampleCount - 1 do
  begin
    if i mod 10 <> 0 then Continue;

    Sample := PSmallInt(buffer + i * ChannelCount * (DEFAULT_BITS div 8))^;
    SampleValue := Abs(Sample) / 32768.0;

    // Распределяем энергию по бэндам с разными коэффициентами
    for j := 0 to High(FEqBands) do
    begin
      Energy := SampleValue * BandFactors[j] * (1.2 - j * 0.15);
      FEqBands[j] := FEqBands[j] + Energy * Energy;
    end;
  end;

  // Обрабатываем бэнды
  for j := 0 to High(FEqBands) do
  begin
    FEqBands[j] := Sqrt(FEqBands[j] / (SampleCount / 10));
    FEqBands[j] := Log10(FEqBands[j] * 50 + 1) * 0.8;

    if FEqBands[j] > FEqBandsDecay[j] then
      FEqBandsDecay[j] := FEqBands[j]
    else
      FEqBandsDecay[j] := FEqBandsDecay[j] * (0.88 + j * 0.02);

    FEqBandsDecay[j] := Min(1.0, Max(0, FEqBandsDecay[j]));
    FEqBands[j] := 0;
  end;
end;

procedure TXmpAudioPlayer.ResetPlayback;
begin
  if FXmpContext <> nil then
  begin
    xmp_restart_module(FXmpContext);
  end;
end;

class procedure TXmpAudioPlayer.AudioCallback(bufferData: pointer; frames: LongWord); cdecl;
var
  {%H-}SamplesRendered: Integer;
begin
  if FCurrentPlayer = nil then Exit;

  with FCurrentPlayer do
  begin
    FPositionLock.Enter;
    try
      if (FXmpContext = nil) or FIsPaused then
      begin
        FillChar(bufferData^, frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8), 0);
        Exit;
      end;

      // Рендерим звук в буфер
      SamplesRendered := xmp_play_buffer(
        FXmpContext,
        bufferData,

       frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8),
        Integer(FLoopMode)
      );

      // TTF анализ
      AnalyzeAudioBuffer(bufferData, frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8));

      // Проверяем окончание трека
      xmp_get_frame_info(FXmpContext, FFrameInfo);


      if FFrameInfo.time >= FFrameInfo.total_time then
      begin
         if Assigned(FOnEnd) and (not FLoopMode) then
          begin
            FOnEnd(FCurrentPlayer, FCurrentTrack, True);
            FTrackEndTriggered := True;
          end;

          if FLoopMode then
          begin
            FTrackEndTriggered := False;
          end;


        ResetPlayback;
    end;

    finally
      FPositionLock.Leave;
      if FTrackEndTriggered then InternalStop(True);
    end;
  end;
end;

procedure TXmpAudioPlayer.CheckError(Condition: Boolean; const Msg: string);
begin
  if Condition and Assigned(FOnError) then
    FOnError(Self, Msg);
end;

procedure TXmpAudioPlayer.InternalStop(ClearModule: Boolean);
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

      if ClearModule then
        FreeModuleData;

    FIsPaused := False;
    FTrackEndTriggered := False;

    if Assigned(FOnStop) then
      FOnStop(Self, FCurrentTrack);
    end;//
  finally
    FPositionLock.Leave;
  end;
end;

procedure TXmpAudioPlayer.Play(const MusicFile: String; Track: Integer);
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

    // Загружаем новый модуль
    try
      LoadModuleFile(MusicFile);
      FCurrentTrack := Track;

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

procedure TXmpAudioPlayer.Pause;
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

procedure TXmpAudioPlayer.Resume;
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

procedure TXmpAudioPlayer.Stop;
begin
  InternalStop;
end;

procedure TXmpAudioPlayer.SetPosition(PositionMs: Integer);
begin
  FPositionLock.Enter;
  try
    if FXmpContext <> nil then
    begin
      xmp_seek_time(FXmpContext, PositionMs);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TXmpAudioPlayer.GetPosition: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if FXmpContext <> nil then
    begin
      xmp_get_frame_info(FXmpContext, FFrameInfo);
      Result := FFrameInfo.time;
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TXmpAudioPlayer.GetDuration: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if FXmpContext <> nil then
    begin
      xmp_get_frame_info(FXmpContext, FFrameInfo);
      Result := FFrameInfo.total_time;
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TXmpAudioPlayer.SetLoopMode(Mode: Boolean);
begin
  FLoopMode := Mode;
  // XMP автоматически обрабатывает loop через параметр в xmp_play_buffer
end;

function TXmpAudioPlayer.GetLoopMode: Boolean;
begin
  Result := FLoopMode;
end;

function TXmpAudioPlayer.IsPlaying: Boolean;
begin
  Result := (FCurrentPlayer = Self) and not FIsPaused and (FXmpContext <> nil);
end;

function TXmpAudioPlayer.IsPaused: Boolean;
begin
  Result := FIsPaused;
end;

function TXmpAudioPlayer.GetCurrentTrack: Integer;
begin
  Result := FCurrentTrack;
end;

function TXmpAudioPlayer.GetCurrentFile: String;
begin
  Result := FFilename;
end;

function TXmpAudioPlayer.GetTrackCount: Integer;
begin
  Result := 1; // XMP обычно обрабатывает однодорожечные модули
end;

function TXmpAudioPlayer.GetEQBandsDecay: TEqBandsDecay;
begin
  Result := FEqBandsDecay;
end;

// Event property getters/setters
function TXmpAudioPlayer.GetOnPlay: TPlayEvent;
begin
  Result := FOnPlay;
end;

function TXmpAudioPlayer.GetOnPause: TPauseEvent;
begin
  Result := FOnPause;
end;

function TXmpAudioPlayer.GetOnStop: TStopEvent;
begin
  Result := FOnStop;
end;

function TXmpAudioPlayer.GetOnEnd: TEndEvent;
begin
  Result := FOnEnd;
end;

function TXmpAudioPlayer.GetOnError: TErrorEvent;
begin
  Result := FOnError;
end;

procedure TXmpAudioPlayer.SetOnPlay(AEvent: TPlayEvent);
begin
  FOnPlay := AEvent;
end;

procedure TXmpAudioPlayer.SetOnPause(AEvent: TPauseEvent);
begin
  FOnPause := AEvent;
end;

procedure TXmpAudioPlayer.SetOnStop(AEvent: TStopEvent);
begin
  FOnStop := AEvent;
end;

procedure TXmpAudioPlayer.SetOnEnd(AEvent: TEndEvent);
begin
  FOnEnd := AEvent;
end;

procedure TXmpAudioPlayer.SetOnError(AEvent: TErrorEvent);
begin
  FOnError := AEvent;
end;

end.
