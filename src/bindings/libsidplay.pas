unit libsidplay;

{$mode objfpc}{$H+}
{$packrecords c}

interface

uses
  SysUtils, dynlibs;

const
  {$IFDEF MSWINDOWS}
  SIDLIB = 'libsidplayfp.dll';
  {$ELSE}
  {$IFDEF DARWIN}
  SIDLIB = 'libsidplayfp.dylib';
  {$ELSE}
  SIDLIB = 'libsidplayfp.so';
  {$ENDIF}
  {$ENDIF}

  MAX_POWER_ON_DELAY = $1FFF;
  DEFAULT_POWER_ON_DELAY: UInt16 = MAX_POWER_ON_DELAY;
  DEFAULT_SAMPLING_FREQ: UInt32 = 44100;

type
  TUint8 = Byte;
  PUint8 = ^TUint8;
  TUint32 = Cardinal;
  TUint16 = Word;

  TShortArray = array[0..0] of SmallInt;
  PShortArray = ^TShortArray;

  playback_t = (MONO = 1, STEREO);
  sid_model_t = (MOS6581, MOS8580);
  sid_cw_t = (AVERAGE, WEAK, STRONG);
  cia_model_t = (MOS6526, MOS8521, MOS6526W4485);
  c64_model_t = (PAL, NTSC, OLD_NTSC, DREAN, PAL_M);
  sampling_method_t = (INTERPOLATE, RESAMPLE_INTERPOLATE);

  player_state_t = (
    playerError = 0,
    playerRunning,
    playerPaused,
    playerStopped,
    playerRestart,
    playerExit,
    playerFast = 128,
    playerFastRestart = playerRestart,
    playerFastExit = playerExit
  );

  PSidConfig = ^TSidConfig;
  TSidConfig = record
    DefaultC64Model: c64_model_t;
    ForceC64Model: Boolean;
    DefaultSidModel: sid_model_t;
    ForceSidModel: Boolean;
    DigiBoost: Boolean;
    CiaModel: cia_model_t;
    Playback: playback_t;
    Frequency: UInt32;
    SecondSidAddress: UInt16;
    ThirdSidAddress: UInt16;
    SidEmulation: Pointer;
    LeftVolume: UInt32;
    RightVolume: UInt32;
    PowerOnDelay: UInt16;
    FastSampling: Boolean;
    SamplingMethode: sampling_method_t;
  end;

var
  // ROM functions
  loadRom: procedure(kernal, basic, character: Byte); cdecl;
  sidplayfp_setKernal: procedure(rom: PUint8); cdecl;
  sid_Set_Basic: procedure(rom: PUint8); cdecl;
  sid_Set_Chargen: procedure(rom: PUint8); cdecl;
  
  // Core functions
  sid_Create: function(): Pointer; cdecl;
  sid_Config: function(): Boolean; cdecl;
  error: function(): PChar; cdecl;
  
  // Playback control
  sid_Select_Song: function(song: integer): integer; cdecl;
  sid_load: function(oneFileFormatSidtune: Pointer; sidtuneLength: TUint32; songnum: Integer): Boolean; cdecl;
  sid_play: function(buffer: PByte; count: Uint32): Integer; cdecl;
  isPlaying: function(): Boolean; cdecl;
  sid_stop: procedure(); cdecl;
  
  // Configuration
  sid_Set_Digiboost: procedure(dboost: Boolean); cdecl;
  sid_Set_Frequency: procedure(freq: integer); cdecl;
  sid_Set_Playback: procedure(state: integer); cdecl;
  sid_Set_FastSampling: procedure(fsample: Boolean); cdecl;
  sid_Set_SamplingMethode: procedure(smethode: integer); cdecl;
  sid_Set_CiaModel: procedure(ciamodel: integer); cdecl;
  sid_Set_Model: procedure(sidmodel: integer); cdecl;
  sid_Set_ForceSidModel: procedure(forcemodel: Boolean); cdecl;
  sid_Set_C64Model: procedure(c64model: Integer); cdecl;
  
  // Information
  sid_Get_Song_info: function(oneFileFormatSidtune: Pointer; sidtuneLength: Integer): PChar; cdecl;
  sid_Get_Subsongs: function(oneFileFormatSidtune: Pointer; sidtuneLength: TUint32): Integer; cdecl;
  
  // Utility functions
  fastForward: function(percent: Integer): Boolean; cdecl;
  debug: procedure(enable: Boolean; outFile: Pointer); cdecl;
  mute: procedure(sidNum, voice: int32; enable: Boolean); cdecl;
  timeMs: function(): TUint32; cdecl;
  getCia1TimerA: function(): int16; cdecl;
  sid_GetStatus: function(): Boolean; cdecl;

procedure LoadSidLibrary(const LibraryName: string = SIDLIB);
function SidLibraryLoaded: Boolean;

implementation

var
  library_handle: TLibHandle = NilHandle;

procedure LoadProc(var fn_var; const fn_name: string);
begin
  pointer(fn_var) := GetProcedureAddress(library_handle, fn_name);
  if pointer(fn_var) = nil then
    raise Exception.CreateFmt('Could not load procedure "%s"', [fn_name]);
end;

procedure LoadSidLibrary(const LibraryName: string);
begin
  if library_handle <> NilHandle then
    Exit; // Already loaded

  library_handle := LoadLibrary(LibraryName);
  if library_handle = NilHandle then
    raise Exception.CreateFmt('Could not load library "%s"', [LibraryName]);

  try
    // ROM functions
    LoadProc(loadRom, 'loadRom');
    LoadProc(sidplayfp_setKernal, 'sidplayfp_setKernal');
    LoadProc(sid_Set_Basic, 'sid_Set_Basic');
    LoadProc(sid_Set_Chargen, 'sid_Set_Chargen');
    
    // Core functions
    LoadProc(sid_Create, 'sid_Create');
    LoadProc(sid_Config, 'sid_Config');
    LoadProc(error, 'error');
    
    // Playback control
    LoadProc(sid_Select_Song, 'sid_Select_Song');
    LoadProc(sid_load, 'sid_load');
    LoadProc(sid_play, 'sid_play');
    LoadProc(isPlaying, 'isPlaying');
    LoadProc(sid_stop, 'sid_stop');
    
    // Configuration
    LoadProc(sid_Set_Digiboost, 'sid_Set_Digiboost');
    LoadProc(sid_Set_Frequency, 'sid_Set_Frequency');
    LoadProc(sid_Set_Playback, 'sid_Set_Playback');
    LoadProc(sid_Set_FastSampling, 'sid_Set_FastSampling');
    LoadProc(sid_Set_SamplingMethode, 'sid_Set_SamplingMethode');
    LoadProc(sid_Set_CiaModel, 'sid_Set_CiaModel');
    LoadProc(sid_Set_Model, 'sid_Set_Model');
    LoadProc(sid_Set_ForceSidModel, 'sid_Set_ForceSidModel');
    LoadProc(sid_Set_C64Model, 'sid_Set_C64Model');
    
    // Information
    LoadProc(sid_Get_Song_info, 'sid_Get_Song_info');
    LoadProc(sid_Get_Subsongs, 'sid_Get_Subsongs');
    
    // Utility functions
    LoadProc(fastForward, 'fastForward');
    LoadProc(debug, 'debug');
    LoadProc(mute, 'mute');
    LoadProc(timeMs, 'timeMs');
    LoadProc(getCia1TimerA, 'getCia1TimerA');
    LoadProc(sid_GetStatus, 'sid_GetStatus');

  except
    UnloadLibrary(library_handle);
    library_handle := NilHandle;
    raise;
  end;
end;

function SidLibraryLoaded: Boolean;
begin
  Result := library_handle <> NilHandle;
end;

finalization
  if library_handle <> NilHandle then
    UnloadLibrary(library_handle);

end.
