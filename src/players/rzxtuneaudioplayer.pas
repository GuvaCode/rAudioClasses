unit rZxTuneAudioPlayer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, libZxTune, libraudio, CommonTypes,
  rAudioIntf, contnrs, syncobjs, math;

type
  { TZxTuneAudioPlayer }
  TZxTuneAudioPlayer = class(TInterfacedObject, IMusicPlayer)
  private
    FStream: TAudioStream;
    FFilename: string;
    FFileData: Pointer;
    FFileSize: NativeUInt;
    FZxTuneData: ZXTuneHandle;
    FZxTuneModule: ZXTuneHandle;
    FZxTunePlayer: ZXTuneHandle;
    FIsPaused: Boolean;
    FLoopMode: Boolean;
    FCurrentTrack: Integer;
    FPositionLock: TCriticalSection;
    FTrackEndTriggered: Boolean;
    FModuleInfo: ZXTuneModuleInfo;

    FEqBands: TEqBands;
    FEqBandsDecay: TEqBandsDecay;

    // Event handlers
    FOnPlay: TPlayEvent;
    FOnPause: TPauseEvent;
    FOnStop: TStopEvent;
    FOnEnd: TEndEvent;
    FOnError: TErrorEvent;

    class var FPlayers: TFPHashList;
    class var FCurrentPlayer: TZxTuneAudioPlayer;

    class constructor ClassCreate;
    class destructor ClassDestroy;

    procedure InitializeAudioStream;
    procedure ResetPlayback;
    class procedure AudioCallback(bufferData: pointer; frames: LongWord); static; cdecl;
    procedure InternalStop(ClearTune: Boolean = True);
    procedure CheckError(Condition: Boolean; const Msg: string);
    procedure LoadModuleFile(const MusicFile: string);
    procedure FreeModuleData;

    procedure AnalyzeAudioBuffer(buffer: PByte; size: Integer);

    const
      DEFAULT_FREQ = 44100;
      DEFAULT_BITS = 16;
      DEFAULT_CHANNELS = 2;
      BUFFER_SIZE = 8192; // Размер буфера для рендеринга звука

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

{ TZxTuneAudioPlayer }

class constructor TZxTuneAudioPlayer.ClassCreate;
begin
  FPlayers := TFPHashList.Create;
  FCurrentPlayer := nil;
end;

class destructor TZxTuneAudioPlayer.ClassDestroy;
begin
  FPlayers.Free;
end;

constructor TZxTuneAudioPlayer.Create;
var i: integer;
begin
  inherited Create;
  FTrackEndTriggered := False;
  FIsPaused := False;
  FLoopMode := False;
  FCurrentTrack := 0;
  FPositionLock := TCriticalSection.Create;
  FFileData := nil;
  FFileSize := 0;
  FZxTuneData := nil;
  FZxTuneModule := nil;
  FZxTunePlayer := nil;



  for i := 0 to EQ_BANDS - 1 do
  begin
    FeqBands[i] := 0;
    FeqBandsDecay[i] := 0;
   end;


  InitializeAudioStream;
end;

destructor TZxTuneAudioPlayer.Destroy;
begin
  InternalStop;
  FreeModuleData;

  FPositionLock.Free;
  inherited Destroy;
end;

procedure TZxTuneAudioPlayer.InitializeAudioStream;
begin
  SetAudioStreamBufferSizeDefault(BUFFER_SIZE);
  FStream := LoadAudioStream(DEFAULT_FREQ, DEFAULT_BITS, DEFAULT_CHANNELS);
  if not IsAudioStreamReady(FStream) then
    raise Exception.Create('Failed to initialize audio stream');

  FPlayers.Add(IntToStr(PtrInt(Self)), Self);
  SetAudioStreamCallback(FStream, @AudioCallback);
end;

procedure TZxTuneAudioPlayer.LoadModuleFile(const MusicFile: string);
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

    FZxTuneData := ZXTune_CreateData(FFileData, FFileSize);
    if FZxTuneData = nil then
      raise Exception.Create('Failed to create ZXTune data');

    FZxTuneModule := ZXTune_OpenModule(FZxTuneData);
    if FZxTuneModule = nil then
      raise Exception.Create('Failed to open ZXTune module');

    if not ZXTune_GetModuleInfo(FZxTuneModule, FModuleInfo) then
      raise Exception.Create('Failed to get module info');

    FZxTunePlayer := ZXTune_CreatePlayer(FZxTuneModule);
    if FZxTunePlayer = nil then
      raise Exception.Create('Failed to create ZXTune player');

    FFilename := MusicFile;
  except
    FreeModuleData;
    raise;
  end;
end;

function GetFileSize(const FileName: string): LongInt;
var
  F: File;
begin
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult = 0 then
  begin
    Result := FileSize(F);
    Close(F);
  end
  else
    Result := 0;
end;

procedure TZxTuneAudioPlayer.FreeModuleData;
begin
  if FZxTunePlayer <> nil then
  begin
    ZXTune_DestroyPlayer(FZxTunePlayer);
    FZxTunePlayer := nil;
  end;

  if FZxTuneModule <> nil then
  begin
    ZXTune_CloseModule(FZxTuneModule);
    FZxTuneModule := nil;
  end;

  if FZxTuneData <> nil then
  begin
    ZXTune_CloseData(FZxTuneData);
    FZxTuneData := nil;
  end;

  if FFileData <> nil then
  begin
    FreeMem(FFileData);
    FFileData := nil;
    FFileSize := 0;
  end;
end;


procedure TZxTuneAudioPlayer.AnalyzeAudioBuffer(buffer: PByte; size: Integer);
{$I BandAnalyzer.inc}
end;

procedure TZxTuneAudioPlayer.ResetPlayback;
begin
  if FZxTunePlayer <> nil then
  begin
    ZXTune_ResetSound(FZxTunePlayer);
  end;
end;

class procedure TZxTuneAudioPlayer.AudioCallback(bufferData: pointer; frames: LongWord); cdecl;
var
  SamplesRendered, FrameDuration, LoopPositionMs: Integer;
begin
  if FCurrentPlayer = nil then Exit;

  with FCurrentPlayer do
  begin
    FPositionLock.Enter;
    try
      if (FZxTunePlayer = nil) or FIsPaused then
      begin
        FillChar(bufferData^, frames * DEFAULT_CHANNELS * (DEFAULT_BITS div 8), 0);
        Exit;
      end;

      // Рендерим звук в буфер

      SamplesRendered := ZXTune_RenderSound(
        FZxTunePlayer,
        bufferData,
        frames
      );

     // TTF
     AnalyzeAudioBuffer(bufferData, frames);

    if GetPosition >= GetDuration then
    begin
      if Assigned(FOnEnd) and (not FLoopMode) then
      begin
        FOnEnd(FCurrentPlayer, FCurrentTrack, true);
        FTrackEndTriggered := True;
      end;
      if FCurrentPlayer.GetLoopMode then
      begin
        ResetPlayback;
        if FModuleInfo.LoopFrame >= 0 then
        begin
          // Получаем длительность одного фрейма в микросекундах
          FrameDuration := ZXTune_GetDuration(FZxTunePlayer);
          if FrameDuration <= 0 then
            FrameDuration := 20000; // 20ms по умолчанию

          // Рассчитываем позицию в миллисекундах: (LoopFrame * FrameDuration) / 1000
          LoopPositionMs := (FModuleInfo.LoopFrame * FrameDuration) div 1000;

          // Устанавливаем позицию
          SetPosition(LoopPositionMs);
        end;
       FTrackEndTriggered := False;
      end;
    end;


    finally
      FPositionLock.Leave;
      if FTrackEndTriggered = True then InternalStop(True);
    end;
  end;
end;

procedure TZxTuneAudioPlayer.CheckError(Condition: Boolean; const Msg: string);
begin
  if Condition and Assigned(FOnError) then
    FOnError(Self, Msg);
end;




procedure TZxTuneAudioPlayer.InternalStop(ClearTune: Boolean);
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

    if ClearTune then
      FreeModuleData;

    FIsPaused := False;
    FTrackEndTriggered := False;

    if Assigned(FOnStop) then
      FOnStop(Self, FCurrentTrack);
    end;///
  finally
    FPositionLock.Leave;
  end;
end;






procedure TZxTuneAudioPlayer.Play(const MusicFile: String; Track: Integer);
var   Success: Boolean;
      SuccesBuffer: array[0..255] of AnsiChar;
begin
  if not FileExists(MusicFile) then
  begin
    CheckError(True, 'File not found: ' + MusicFile);
    Exit;
  end;

  FPositionLock.Enter;
  try
    // Stop current playback
    if IsAudioStreamPlaying(FStream) then InternalStop;

    // Load new module
    try


      LoadModuleFile(MusicFile);
      FCurrentTrack := Track;

      // Start playback
      FCurrentPlayer := Self;
      PlayAudioStream(FStream);
      FIsPaused := False;
      FTrackEndTriggered := False;

      {
      Success := ZXTune_GetModuleAttribute(FZxTuneModule, 'Type', @SuccesBuffer[0], SizeOf(SuccesBuffer));
      WriteLn('Module type: ', string(SuccesBuffer));

      Success := ZXTune_GetModuleAttribute(FZxTuneModule, 'Title', @SuccesBuffer[0], SizeOf(SuccesBuffer));
      WriteLn('Module title: ', string(SuccesBuffer));

      Success := ZXTune_GetModuleAttribute(FZxTuneModule, 'Author', @SuccesBuffer[0], SizeOf(SuccesBuffer));
      WriteLn('Module author: ', string(SuccesBuffer));
      }

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

procedure TZxTuneAudioPlayer.Pause;
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

procedure TZxTuneAudioPlayer.Resume;
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

procedure TZxTuneAudioPlayer.Stop;
begin
  InternalStop;
end;

procedure TZxTuneAudioPlayer.SetPosition(PositionMs: Integer);
var
  SamplePos: NativeUInt;
begin
  FPositionLock.Enter;
  try
    if FZxTunePlayer <> nil then
    begin
      SamplePos := (PositionMs * DEFAULT_FREQ) div 1000;
      ZXTune_SeekSound(FZxTunePlayer, SamplePos);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TZxTuneAudioPlayer.GetPosition: Integer;
var
  Samples: NativeUInt;
  Frequency: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if FZxTunePlayer <> nil then
    begin
      // Get current position in samples
      Samples := ZXTune_GetCurrentPosition(FZxTunePlayer);

      // Get current frequency setting
      Frequency := DEFAULT_FREQ;

      // Convert samples to milliseconds: (samples / channels) / frequency * 1000
      Result := Round((Samples / DEFAULT_CHANNELS) / Frequency * 1000)*2;
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TZxTuneAudioPlayer.GetDuration: Integer;
var
  FrameDuration: Integer;
begin
 Result := 0;
  FPositionLock.Enter;
  try
    if FZxTuneModule <> nil then
    begin
      // Get frame duration in microseconds (default to 20ms if not available)
      FrameDuration := ZXTune_GetDuration(FZxTunePlayer);
      if FrameDuration <= 0 then
        FrameDuration := 20000; // Default 20ms frame duration

      // Calculate duration: (frames * frame_duration) / 1000
      Result := Round((FModuleInfo.Frames * FrameDuration) / 1000);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure TZxTuneAudioPlayer.SetLoopMode(Mode: Boolean);
begin

  if FZxTunePlayer <> nil then
  begin
    if (Mode = True) and (ZXTune_SetPlayerLoopTrack(FZxTunePlayer, 1)) then
    FLoopMode := True
    else
     if (Mode = False) and (ZXTune_SetPlayerLoopTrack(FZxTunePlayer, 0)) then
     FLoopMode := False;
  end;
end;

function TZxTuneAudioPlayer.GetLoopMode: Boolean;
begin
 if FZxTunePlayer <> nil then
 begin
   if ZXTune_GetPlayerLoopTrack(FZxTunePlayer) > 0 then
   FLoopMode := True else
    FLoopMode := False;
 end;
  Result := FLoopMode;
end;

function TZxTuneAudioPlayer.IsPlaying: Boolean;
begin
  Result := (FCurrentPlayer = Self) and not FIsPaused and (FZxTunePlayer <> nil);
end;

function TZxTuneAudioPlayer.IsPaused: Boolean;
begin
  Result := FIsPaused;
end;

function TZxTuneAudioPlayer.GetCurrentTrack: Integer;
begin
  Result := FCurrentTrack;
end;

function TZxTuneAudioPlayer.GetCurrentFile: String;
begin
  Result := FFilename;
end;

function TZxTuneAudioPlayer.GetTrackCount: Integer;
begin
  Result := 1; // ZXTune обычно обрабатывает однодорожечные модули
end;


function TZxTuneAudioPlayer.GetEQBandsDecay: TEqBandsDecay;
begin
 result := Self.FEqBandsDecay;
end;

// Event property getters/setters
function TZxTuneAudioPlayer.GetOnPlay: TPlayEvent;
begin
  Result := FOnPlay;
end;

function TZxTuneAudioPlayer.GetOnPause: TPauseEvent;
begin
  Result := FOnPause;
end;

function TZxTuneAudioPlayer.GetOnStop: TStopEvent;
begin
  Result := FOnStop;
end;

function TZxTuneAudioPlayer.GetOnEnd: TEndEvent;
begin
  Result := FOnEnd;
end;

function TZxTuneAudioPlayer.GetOnError: TErrorEvent;
begin
  Result := FOnError;
end;

procedure TZxTuneAudioPlayer.SetOnPlay(AEvent: TPlayEvent);
begin
  FOnPlay := AEvent;
end;

procedure TZxTuneAudioPlayer.SetOnPause(AEvent: TPauseEvent);
begin
  FOnPause := AEvent;
end;

procedure TZxTuneAudioPlayer.SetOnStop(AEvent: TStopEvent);
begin
  FOnStop := AEvent;
end;

procedure TZxTuneAudioPlayer.SetOnEnd(AEvent: TEndEvent);
begin
  FOnEnd := AEvent;
end;

procedure TZxTuneAudioPlayer.SetOnError(AEvent: TErrorEvent);
begin
  FOnError := AEvent;
end;

end.
