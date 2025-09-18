unit rHivelyAudioPlayer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, libhvl, libraudio,
  rAudioIntf, contnrs, syncobjs, math;

type
  { THivelyAudioPlayer }
  THivelyAudioPlayer = class(TInterfacedObject, IMusicPlayer)
  private
    FStream: TAudioStream;
    FFilename: string;
    FHivelyTune: Phvl_tune;
    FIsPaused: Boolean;
    FLoopMode: Boolean;
    FCurrentTrack: Integer;
    FPositionLock: TCriticalSection;
    FTrackEndTriggered: Boolean;

    // Event handlers
    FOnPlay: TPlayEvent;
    FOnPause: TPauseEvent;
    FOnStop: TStopEvent;
    FOnEnd: TEndEvent;
    FOnError: TErrorEvent;

    FEqBands: TEqBands;
    FEqBandsDecay: TEqBandsDecay;

    class var FPlayers: TFPHashList;
    class var FCurrentPlayer: THivelyAudioPlayer;

    class constructor ClassCreate;
    class destructor ClassDestroy;

    procedure InitializeAudioStream;
    procedure ResetPlayback;
    class procedure AudioCallback(bufferData: pointer; frames: LongWord); static; cdecl;
    procedure InternalStop(ClearTune: Boolean = True);
    procedure CheckError(Condition: Boolean; const Msg: string);

    procedure AnalyzeAudioBuffer(buffer: PByte; size: Integer);

    const
      DEFAULT_FREQ = 44100;
      DEFAULT_BITS = 16;
      DEFAULT_CHANNELS = 2;
      FRAME_LEN = DEFAULT_FREQ * 2 * DEFAULT_CHANNELS div 50; // 3528 bytes
      Q_FACTOR = 4;

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

var
  FHVLBuffer: packed array[0..pred(3528)] of byte;

{ THivelyAudioPlayer }

class constructor THivelyAudioPlayer.ClassCreate;
begin
  FPlayers := TFPHashList.Create;
  FCurrentPlayer := nil;
end;

class destructor THivelyAudioPlayer.ClassDestroy;
begin
  FPlayers.Free;
end;

constructor THivelyAudioPlayer.Create;
begin
  inherited Create;
  FTrackEndTriggered := False;
  FIsPaused := False;
  FLoopMode := False;
  FCurrentTrack := 0;
  FPositionLock := TCriticalSection.Create;

  // Load library and initialize
//  if not libhvl.LoadLib(FindLibName(libhvl.library_name)) then
 //   raise Exception.Create('Failed to load Hively library');

  hvl_InitReplayer();
  InitializeAudioStream;
end;

destructor THivelyAudioPlayer.Destroy;
begin
  InternalStop;
  FPositionLock.Free;
  inherited Destroy;
end;

procedure THivelyAudioPlayer.InitializeAudioStream;
begin
  SetAudioStreamBufferSizeDefault(FRAME_LEN);
  FStream := LoadAudioStream(DEFAULT_FREQ, DEFAULT_BITS, DEFAULT_CHANNELS);
  if not IsAudioStreamReady(FStream) then
    raise Exception.Create('Failed to initialize audio stream');

  FPlayers.Add(IntToStr(PtrInt(Self)), Self);
  SetAudioStreamCallback(FStream, @AudioCallback);
end;

procedure THivelyAudioPlayer.ResetPlayback;
begin
  if Assigned(FHivelyTune) then
  begin
    hvl_FreeTune(FHivelyTune);
    FHivelyTune := hvl_LoadTune(PChar(FFileName), DEFAULT_FREQ, 1);
    if Assigned(FHivelyTune) then
      FHivelyTune^.ht_SongEndReached := 0;
  end;
end;

class procedure THivelyAudioPlayer.AudioCallback(bufferData: pointer; frames: LongWord); cdecl;
const
  HVLBuffer_Count: integer = 0;
  HVLBuffer_Index: integer = 0;
var
  RLABuffer: PByte absolute bufferData;
  RLABuffer_Index: integer = 0;
  ByteCountToCopy: SizeInt;
begin
  if (frames = 0) or (FCurrentPlayer = nil) or (FCurrentPlayer.FHivelyTune = nil) then
    Exit;
  {
  // Воспроизводим аудио
  if hvl_DecodeFrame(FCurrentPlayer.FHivelyTune, @FHVLBuffer[0], @FHVLBuffer[2], Q) < 0 then
  begin
    FCurrentPlayer.Stop;
    Exit;
  end;
  }
  // Проверяем завершение трека
  if (FCurrentPlayer.FHivelyTune^.ht_SongEndReached <> 0) then
  begin
    if not FCurrentPlayer.FTrackEndTriggered then
    begin
      FCurrentPlayer.FTrackEndTriggered := True;
      if Assigned(FCurrentPlayer.FOnEnd) then
        FCurrentPlayer.FOnEnd(FCurrentPlayer, 0, true);
    end;
  end
  else
  begin
    // Сбрасываем флаг, если трек ещё не завершён
    FCurrentPlayer.FTrackEndTriggered := False;
  end;

  ByteCountToCopy := frames * Q_FACTOR;
  if ByteCountToCopy > frames * FRAME_LEN then
    Exit;

  if (HVLBuffer_Count = 0) then  // decode buffer
  begin
    hvl_DecodeFrame(FCurrentPlayer.FHivelyTune, @FHVLBuffer[0], @FHVLBuffer[2], Q_FACTOR);
    HVLBuffer_Count := FRAME_LEN;
    HVLBuffer_Index := 0;
  end;

  if (HVLBuffer_Count >= ByteCountToCopy) then // copy buffer
  begin
    Move(FHVLBuffer[HVLBuffer_Index], RLABuffer[RLABuffer_Index], ByteCountToCopy);
    dec(HVLBuffer_Count, ByteCountToCopy);
    inc(HVLBuffer_Index, ByteCountToCopy);
    RLABuffer_Index := 0;
  end
  else // copy->decode->copy buffer
  begin
    Move(FHVLBuffer[HVLBuffer_Index], RLABuffer[RLABuffer_Index], HVLBuffer_Count);
    dec(ByteCountToCopy, HVLBuffer_Count);
    inc(HVLBuffer_Index, HVLBuffer_Count);
    RLABuffer_Index := HVLBuffer_Count;

    hvl_DecodeFrame(FCurrentPlayer.FHivelyTune, @FHVLBuffer[0], @FHVLBuffer[2], Q_FACTOR);
    HVLBuffer_Count := FRAME_LEN;
    HVLBuffer_Index := 0;

    Move(FHVLBuffer[HVLBuffer_Index], RLABuffer[RLABuffer_Index], ByteCountToCopy);
    dec(HVLBuffer_Count, ByteCountToCopy);
    inc(HVLBuffer_Index, ByteCountToCopy);
    RLABuffer_Index := 0;

    FCurrentPlayer.AnalyzeAudioBuffer(bufferData, frames);
  end;
end;

procedure THivelyAudioPlayer.CheckError(Condition: Boolean; const Msg: string);
begin
  if Condition and Assigned(FOnError) then
    FOnError(Self, Msg);
end;

procedure THivelyAudioPlayer.AnalyzeAudioBuffer(buffer: PByte; size: Integer);
{$I BandAnalyzer.inc}
end;

procedure THivelyAudioPlayer.InternalStop(ClearTune: Boolean);
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

    if ClearTune and Assigned(FHivelyTune) then
    begin
      hvl_FreeTune(FHivelyTune);
      FHivelyTune := nil;
    end;

    FIsPaused := False;
    FTrackEndTriggered := False;

    if Assigned(FOnStop) then
      FOnStop(Self, FCurrentTrack);

    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure THivelyAudioPlayer.Play(const MusicFile: String; Track: Integer);
begin
  if not FileExists(MusicFile) then
  begin
    CheckError(True, 'File not found: ' + MusicFile);
    Exit;
  end;

  FPositionLock.Enter;
  try
    // Stop current playback
    InternalStop;

    // Load new tune
    FFilename := MusicFile;
    FCurrentTrack := Track;
    FHivelyTune := hvl_LoadTune(PChar(FFilename), DEFAULT_FREQ, 1);

    if FHivelyTune = nil then
    begin
      CheckError(True, 'Failed to load Hively tune: ' + FFilename);
      Exit;
    end;
     CheckError(true,IntToStr(FHivelyTune^.ht_PlayingTime));
    // Start playback
    FCurrentPlayer := Self;
    PlayAudioStream(FStream);
    FIsPaused := False;
    FTrackEndTriggered := False;

    if Assigned(FOnPlay) then
      FOnPlay(Self, FCurrentTrack);
  finally
    FPositionLock.Leave;
  end;
end;

procedure THivelyAudioPlayer.Pause;
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

procedure THivelyAudioPlayer.Resume;
begin
  FPositionLock.Enter;
  try
    if (FCurrentPlayer = Self) and FIsPaused then
    begin
      ResumeAudioStream(FStream);
      FIsPaused := False;
    end;
  finally
    FPositionLock.Leave;
  end;
end;

procedure THivelyAudioPlayer.Stop;
begin
  InternalStop;
end;

procedure THivelyAudioPlayer.SetPosition(PositionMs: Integer);
begin
  // HivelyTracker doesn't support seeking, so we implement by stopping and restarting

end;

function THivelyAudioPlayer.GetPosition: Integer;
begin

  Result := 0;
 { FPositionLock.Enter;
  try
    if Assigned(FHivelyTune) then
      Result :=hvl_GetCurrentFrame(FHivelyTune);
  finally
    FPositionLock.Leave;
  end; }
end;



function THivelyAudioPlayer.GetDuration: Integer;
begin
  Result := 0;
 { FPositionLock.Enter;
  try
    if Assigned(FHivelyTune) then
      Result := FHivelyTune^.ht_PlayingTime; // Convert to milliseconds
  finally
    FPositionLock.Leave;
  end;}
end;

procedure THivelyAudioPlayer.SetLoopMode(Mode: Boolean);
begin
  FLoopMode := Mode;
end;

function THivelyAudioPlayer.GetLoopMode: Boolean;
begin
  Result := FLoopMode;
end;

function THivelyAudioPlayer.IsPlaying: Boolean;
begin
  Result := (FCurrentPlayer = Self) and not FIsPaused and (FHivelyTune <> nil);
end;

function THivelyAudioPlayer.IsPaused: Boolean;
begin
  Result := FIsPaused;
end;

function THivelyAudioPlayer.GetCurrentTrack: Integer;
begin
  Result := FCurrentTrack;
end;

function THivelyAudioPlayer.GetCurrentFile: String;
begin
  Result := FFilename;
end;

function THivelyAudioPlayer.GetTrackCount: Integer;
begin
  Result := 1; // HivelyTracker typically handles single-track modules
end;

function THivelyAudioPlayer.GetEQBandsDecay: TEqBandsDecay;
begin
  result := Self.FEqBandsDecay;
end;


// Event property getters/setters
function THivelyAudioPlayer.GetOnPlay: TPlayEvent;
begin
  Result := FOnPlay;
end;

function THivelyAudioPlayer.GetOnPause: TPauseEvent;
begin
  Result := FOnPause;
end;

function THivelyAudioPlayer.GetOnStop: TStopEvent;
begin
  Result := FOnStop;
end;

function THivelyAudioPlayer.GetOnEnd: TEndEvent;
begin
  Result := FOnEnd;
end;

function THivelyAudioPlayer.GetOnError: TErrorEvent;
begin
  Result := FOnError;
end;

procedure THivelyAudioPlayer.SetOnPlay(AEvent: TPlayEvent);
begin
  FOnPlay := AEvent;
end;

procedure THivelyAudioPlayer.SetOnPause(AEvent: TPauseEvent);
begin
  FOnPause := AEvent;
end;

procedure THivelyAudioPlayer.SetOnStop(AEvent: TStopEvent);
begin
  FOnStop := AEvent;
end;

procedure THivelyAudioPlayer.SetOnEnd(AEvent: TEndEvent);
begin
  FOnEnd := AEvent;
end;

procedure THivelyAudioPlayer.SetOnError(AEvent: TErrorEvent);
begin
  FOnError := AEvent;
end;

end.
