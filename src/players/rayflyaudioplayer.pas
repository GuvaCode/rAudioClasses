unit rAyFlyAudioPlayer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, libayfly, libraudio,
  rAudioIntf, contnrs, syncobjs, ctypes;

type
  { TAyFlyAudioPlayer }
  TAyFlyAudioPlayer = class(TInterfacedObject, IMusicPlayer)
  private
    FStream: TAudioStream;
    FFileName: string;
    FIsPaused: Boolean;
    FSongInfo: Pointer;
    FLoopMode: Boolean;
    FCurrentTrack: Integer;
    FPositionLock: TCriticalSection;
    FSampleRate: LongWord;
    FLoopCount: Integer;
    FLoopCounter: Integer;

    // Event handlers
    FOnPlay: TPlayEvent;
    FOnPause: TPauseEvent;
    FOnStop: TStopEvent;
    FOnEnd: TEndEvent;
    FOnError: TErrorEvent;

    class var FPlayers: TFPHashList;
    class var FCurrentPlayer: TAyFlyAudioPlayer;

    class constructor ClassCreate;
    class destructor ClassDestroy;

    procedure InitializeAudioStream;
    class procedure AudioCallback(bufferData: pointer; frames: LongWord); static; cdecl;

    class function SongEndCallback(arg: pointer): cbool; static; cdecl;
    class procedure SongStopCallback(arg: pointer); static; cdecl;
    procedure InternalStop(ClearSongInfo: Boolean = True);
    procedure CheckError(Condition: Boolean; const Msg: string);

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

{ TAyFlyAudioPlayer }

class constructor TAyFlyAudioPlayer.ClassCreate;
begin
  FPlayers := TFPHashList.Create;
  FCurrentPlayer := nil;
end;

class destructor TAyFlyAudioPlayer.ClassDestroy;
begin
  FPlayers.Free;
end;

constructor TAyFlyAudioPlayer.Create;
begin
  inherited Create;
  FSampleRate := 44100;
  FIsPaused := False;
  FLoopMode := False;
  FLoopCount := 0;
  FLoopCounter := 0;
  FCurrentTrack := 0;

  FPositionLock := TCriticalSection.Create;
  InitializeAudioStream;
end;

destructor TAyFlyAudioPlayer.Destroy;
begin
  InternalStop;
  FPositionLock.Free;
  inherited Destroy;
end;

procedure TAyFlyAudioPlayer.InitializeAudioStream;
begin
  SetAudioStreamBufferSizeDefault(8192);
  FStream := LoadAudioStream(FSampleRate, 16, 2);
  FPlayers.Add(IntToStr(PtrInt(Self)), Self);
  SetAudioStreamCallback(FStream, @AudioCallback);
end;

class procedure TAyFlyAudioPlayer.AudioCallback(bufferData: pointer; frames: LongWord); cdecl;
begin
  if (FCurrentPlayer = nil) or (FCurrentPlayer.FSongInfo = nil) then Exit;
  ay_rendersongbuffer(FCurrentPlayer.FSongInfo, bufferData, frames * 4);
end;

procedure TAyFlyAudioPlayer.CheckError(Condition: Boolean; const Msg: string);
begin
  if Condition and Assigned(FOnError) then
    FOnError(Self, Msg);
end;

procedure TAyFlyAudioPlayer.InternalStop(ClearSongInfo: Boolean);
begin
  FPositionLock.Enter;
  try
    if FCurrentPlayer = Self then
    begin
      StopAudioStream(FStream);
      FCurrentPlayer := nil;
    end;

    if Assigned(FSongInfo) then
    begin
      ay_stopsong(FSongInfo);
      if ClearSongInfo then
      begin
        ay_closesong(FSongInfo);
        FSongInfo := nil;
      end;
    end;

    FIsPaused := False;
    FLoopCounter := 0;

    if Assigned(FOnStop) then
      FOnStop(Self, FCurrentTrack);
  finally
    FPositionLock.Leave;
  end;
end;

class function TAyFlyAudioPlayer.SongEndCallback(arg: pointer): cbool; cdecl;
begin
  Result := False;

  if (FCurrentPlayer = nil) or (FCurrentPlayer.FSongInfo = nil) then Exit;

  if FCurrentPlayer.FLoopMode then
  begin
    // For loop mode, just reset the position
    ay_resetsong(FCurrentPlayer.FSongInfo);
    Result := True;
  end
  else if FCurrentPlayer.FLoopCount > 0 then
  begin
    Inc(FCurrentPlayer.FLoopCounter);
    if FCurrentPlayer.FLoopCounter >= FCurrentPlayer.FLoopCount then
    begin
      Result := True;
      FCurrentPlayer.InternalStop;
    end
    else
    begin
      ay_resetsong(FCurrentPlayer.FSongInfo);
      Result := True;
    end;
  end;

  if Assigned(FCurrentPlayer.FOnEnd) then
    FCurrentPlayer.FOnEnd(FCurrentPlayer, FCurrentPlayer.FCurrentTrack, not Result);
end;

class procedure TAyFlyAudioPlayer.SongStopCallback(arg: pointer); cdecl;
begin
  if (FCurrentPlayer <> nil) and Assigned(FCurrentPlayer.FOnStop) then
    FCurrentPlayer.FOnStop(FCurrentPlayer, FCurrentPlayer.FCurrentTrack);
end;

procedure TAyFlyAudioPlayer.Play(const MusicFile: String; Track: Integer);
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

    // Load new song
    FFileName := MusicFile;
    FCurrentTrack := Track;
    FSongInfo := ay_initsong(PChar(FFileName), FSampleRate);

    if FSongInfo = nil then
    begin
      CheckError(True, 'Failed to load module: ' + FFileName);
      Exit;
    end;

    // Setup callbacks
    ay_setelapsedcallback(FSongInfo, @SongEndCallback, Self);
    ay_setstoppedcallback(FSongInfo, @SongStopCallback, Self);

    // Start playback
    FCurrentPlayer := Self;
    PlayAudioStream(FStream);

    if Assigned(FOnPlay) then
      FOnPlay(Self, FCurrentTrack);
  finally
    FPositionLock.Leave;
  end;
end;

procedure TAyFlyAudioPlayer.Pause;
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

procedure TAyFlyAudioPlayer.Resume;
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

procedure TAyFlyAudioPlayer.Stop;
begin
  InternalStop;
end;

procedure TAyFlyAudioPlayer.SetPosition(PositionMs: Integer);
var
  PosInTicks: Integer;
begin
  FPositionLock.Enter;
  try
    if Assigned(FSongInfo) then
    begin
      PosInTicks := (PositionMs * 50) div 1000; // Convert ms to ticks (1/50 sec)
      ay_seeksong(FSongInfo, PosInTicks);
    end;
  finally
    FPositionLock.Leave;
  end;
end;

function TAyFlyAudioPlayer.GetPosition: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if Assigned(FSongInfo) then
      Result := (ay_getelapsedtime(FSongInfo) * 1000) div 50; // Convert ticks to ms
  finally
    FPositionLock.Leave;
  end;
end;

function TAyFlyAudioPlayer.GetDuration: Integer;
begin
  Result := 0;
  FPositionLock.Enter;
  try
    if Assigned(FSongInfo) then
      Result := (ay_getsonglength(FSongInfo) * 1000) div 50; // Convert ticks to ms
  finally
    FPositionLock.Leave;
  end;
end;

procedure TAyFlyAudioPlayer.SetLoopMode(Mode: Boolean);
begin
  FLoopMode := Mode;
end;

function TAyFlyAudioPlayer.GetLoopMode: Boolean;
begin
  Result := FLoopMode;
end;

function TAyFlyAudioPlayer.IsPlaying: Boolean;
begin
  Result := (FCurrentPlayer = Self) and not FIsPaused and (FSongInfo <> nil);
end;

function TAyFlyAudioPlayer.IsPaused: Boolean;
begin
  Result := FIsPaused;
end;

function TAyFlyAudioPlayer.GetCurrentTrack: Integer;
begin
  Result := FCurrentTrack;
end;

function TAyFlyAudioPlayer.GetCurrentFile: String;
begin
  Result := FFileName;
end;

function TAyFlyAudioPlayer.GetTrackCount: Integer;
begin
  Result := 1; // AyFly typically handles single-track modules
end;

// Event property getters/setters
function TAyFlyAudioPlayer.GetOnPlay: TPlayEvent;
begin
  Result := FOnPlay;
end;

function TAyFlyAudioPlayer.GetOnPause: TPauseEvent;
begin
  Result := FOnPause;
end;

function TAyFlyAudioPlayer.GetOnStop: TStopEvent;
begin
  Result := FOnStop;
end;

function TAyFlyAudioPlayer.GetOnEnd: TEndEvent;
begin
  Result := FOnEnd;
end;

function TAyFlyAudioPlayer.GetOnError: TErrorEvent;
begin
  Result := FOnError;
end;

procedure TAyFlyAudioPlayer.SetOnPlay(AEvent: TPlayEvent);
begin
  FOnPlay := AEvent;
end;

procedure TAyFlyAudioPlayer.SetOnPause(AEvent: TPauseEvent);
begin
  FOnPause := AEvent;
end;

procedure TAyFlyAudioPlayer.SetOnStop(AEvent: TStopEvent);
begin
  FOnStop := AEvent;
end;

procedure TAyFlyAudioPlayer.SetOnEnd(AEvent: TEndEvent);
begin
  FOnEnd := AEvent;
end;

procedure TAyFlyAudioPlayer.SetOnError(AEvent: TErrorEvent);
begin
  FOnError := AEvent;
end;

end.
