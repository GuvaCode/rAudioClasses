unit libayfly;

{$mode objfpc}{$H+}
{$packrecords c}

interface

uses
  ctypes, dynlibs;

const
  // Library version
  AYFLY_VERSION_MAJOR = 0;
  AYFLY_VERSION_MINOR = 0;
  AYFLY_VERSION_PATCH = 25;
  AYFLY_VERSION_STR = '0.0.25';

  // Platform-specific library names
  {$IFDEF WINDOWS}
  LIBRARY_NAME = 'ayfly.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  LIBRARY_NAME = 'libayfly.so.0.0.25';
  {$ENDIF}

type
  // Basic types
  TAYChar = type Char;
  PAYChar = ^TAYChar;
  TAYBool = type cbool;

  // AY mixer types
  TAYMixType = (
    ayMixABC = 0,
    ayMixACB = 1,
    ayMixBAC = 2,
    ayMixBCA = 3,
    ayMixCAB = 4,
    ayMixCBA = 5,
    ayMixMono = 6
  );

  // Callback types
  TAYElapsedCallback = function(arg: Pointer): TAYBool; cdecl;
  TAYStoppedCallback = procedure(arg: Pointer); cdecl;
  TAYEmptyCallback = procedure(song: Pointer); cdecl;
  TAYWriteCallback = procedure(song: Pointer; chip: cuint32; reg, val: Byte); cdecl;

  // Abstract audio interface
  PAbstractAudio = ^TAbstractAudio;
  TAbstractAudio = record end;

  // Z80 context
  PZ80EXContext = ^TZ80EXContext;
  TZ80EXContext = record end;

  // AY chip structure
  TAYChip = record
    // Internal AY chip structure
    // (implementation details are hidden in the C++ library)
  end;

  // AY song info structure
  PAYSongInfo = ^TAYSongInfo;
  TAYSongInfo = record
    Author: PAYChar;           // Song author
    Name: PAYChar;             // Song name
    FilePath: PAYChar;         // Song file path
    PrgName: PAYChar;          // Program name
    TrackName: PAYChar;        // Track name
    CompName: PAYChar;         // Compiler name
    Length: cuint32;           // Song length in 1/50 of second
    Loop: cuint32;             // Loop start position
    is_z80: TAYBool;           // Player is in z80 asm?
    data: Pointer;             // Used for players
    data1: Pointer;            // Used for players
    module: PByte;             // z80 memory or raw song data
    module1: PByte;            // z80 memory or raw song data
    file_data: PByte;          // z80 memory or raw song data
    z80IO: array[0..65535] of Byte; // z80 ports
    file_len: cuint32;         // File length
    module_len: cuint32;       // Module length
    player: PAbstractAudio;    // Player for this song
    z80ctx: PZ80EXContext;     // z80 execution context
    timeElapsed: cuint32;      // Playing time in tacts
    e_callback: TAYElapsedCallback; // Song elapsed callback function
    e_callback_arg: Pointer;   // Argument for elapsed callback
    s_callback: TAYStoppedCallback; // Song stop callback function
    s_callback_arg: Pointer;   // Argument for stop callback
    ay_reg: cuint16;           // Current AY register
    z80_freq: cuint32;         // z80 cpu frequency
    ay_freq: cuint32;          // AY chip frequency
    int_freq: cfloat;          // Interrupts frequency
    sr: cuint32;               // Sample rate
    chip_type: Byte;           // Chip type: AY = 0 or YM = 1
    mix_levels_nr: TAYMixType; // Mix scheme
    int_counter: cint32;
    int_limit: cint32;
    own_player: TAYBool;       // Is player was created during initialization by the library
    stopping: TAYBool;
    ay8910: array[0..1] of TAYChip; // AY chips (up to 2 for Turbo Sound)
    player_num: cint32;
    is_ts: TAYBool;            // 2xAY - Turbo Sound
    ay_oversample: cuint32;    // Higher - better, default = 2
    empty_song: TAYBool;       // True if empty song
    empty_callback: TAYEmptyCallback;
    aywrite_callback: TAYWriteCallback;
  end;

//----------------------------------------------------------
// Section 1: Library loading/unloading
//----------------------------------------------------------

var
  // Library handle
  LibAyflyHandle: TLibHandle = NilHandle;

// Load library
function AyflyLoad(const LibraryName: string = LIBRARY_NAME): Boolean;

// Unload library
procedure AyflyUnload;

// Check if library is loaded
function AyflyIsLoaded: Boolean;

//----------------------------------------------------------
// Section 2: Song initialization and information
//----------------------------------------------------------

var
  // Initialize song from file
  ay_initsong: function(const FilePath: PAYChar; sr: cuint32;
    player: PAbstractAudio = nil): Pointer; cdecl;

  // Initialize song from memory
  ay_initsongindirect: function(module: PByte; sr, size: cuint32;
    player: PAbstractAudio = nil): Pointer; cdecl;

  // Get song info from file
  ay_getsonginfo: function(const FilePath: PAYChar): Pointer; cdecl;

  // Get song info from memory
  ay_getsonginfoindirect: function(module: PByte; type_: PAYChar;
    size: cuint32): Pointer; cdecl;

//----------------------------------------------------------
// Section 3: Song metadata
//----------------------------------------------------------

var
  // Get song name
  ay_getsongname: function(info: Pointer): PAYChar; cdecl;

  // Get song author
  ay_getsongauthor: function(info: Pointer): PAYChar; cdecl;

  // Get song path
  ay_getsongpath: function(info: Pointer): PAYChar; cdecl;

//----------------------------------------------------------
// Section 4: Playback control
//----------------------------------------------------------

var
  // Start song playback
  ay_startsong: procedure(info: Pointer); cdecl;

  // Stop song playback
  ay_stopsong: procedure(info: Pointer); cdecl;

  // Reset song to beginning
  ay_resetsong: procedure(info: Pointer); cdecl;

  // Seek to position
  ay_seeksong: procedure(info: Pointer; new_position: cint32); cdecl;

  // Close song and free resources
  ay_closesong: procedure(var info: Pointer); cdecl;

//----------------------------------------------------------
// Section 5: Playback status
//----------------------------------------------------------

var
  // Check if song is playing
  ay_songstarted: function(info: Pointer): TAYBool; cdecl;

  // Get song length (in 1/50 seconds)
  ay_getsonglength: function(info: Pointer): cuint32; cdecl;

  // Get elapsed time (in 1/50 seconds)
  ay_getelapsedtime: function(info: Pointer): cuint32; cdecl;

  // Get loop position
  ay_getsongloop: function(info: Pointer): cuint32; cdecl;

//----------------------------------------------------------
// Section 6: AY chip control
//----------------------------------------------------------

var
  // Set channel volume (0..1)
  ay_setvolume: procedure(info: Pointer; chnl: cuint32; volume: cfloat;
    chip_num: Byte = 0); cdecl;

  // Get channel volume
  ay_getvolume: function(info: Pointer; chnl: cuint32;
    chip_num: Byte = 0): cfloat; cdecl;

  // Mute/unmute channel
  ay_chnlmute: procedure(info: Pointer; chnl: cuint32; mute: TAYBool;
    chip_num: Byte = 0); cdecl;

  // Check if channel is muted
  ay_chnlmuted: function(info: Pointer; chnl: cuint32;
    chip_num: Byte = 0): TAYBool; cdecl;

//----------------------------------------------------------
// Section 7: Mixer configuration
//----------------------------------------------------------

var
  // Set mixer type
  ay_setmixtype: procedure(info: Pointer; mixType: TAYMixType;
    chip_num: Byte = 0); cdecl;

  // Get mixer type
  ay_getmixtype: function(info: Pointer; chip_num: Byte = 0): TAYMixType; cdecl;

//----------------------------------------------------------
// Section 8: Callbacks
//----------------------------------------------------------

var
  // Set elapsed callback
  ay_setelapsedcallback: procedure(info: Pointer; callback: TAYElapsedCallback;
    callback_arg: Pointer); cdecl;

  // Set stopped callback
  ay_setstoppedcallback: procedure(info: Pointer; callback: TAYStoppedCallback;
    callback_arg: Pointer); cdecl;

//----------------------------------------------------------
// Section 9: Advanced functions
//----------------------------------------------------------

var
  // Render audio to buffer
  ay_rendersongbuffer: function(info: Pointer; buffer: PByte;
    buffer_length: cuint32): cuint32; cdecl;

  // Get AY registers
  ay_getregs: function(info: Pointer; chip_num: Byte = 0): PByte; cdecl;

//----------------------------------------------------------
// Section 10: Frequency control
//----------------------------------------------------------

var
  // Get Z80 frequency
  ay_getz80freq: function(info: Pointer): cuint32; cdecl;

  // Set Z80 frequency
  ay_setz80freq: procedure(info: Pointer; z80_freq: cuint32); cdecl;

  // Get AY frequency
  ay_getayfreq: function(info: Pointer): cuint32; cdecl;

  // Set AY frequency
  ay_setayfreq: procedure(info: Pointer; ay_freq: cuint32); cdecl;

  // Get interrupt frequency
  ay_getintfreq: function(info: Pointer): cfloat; cdecl;

  // Set interrupt frequency
  ay_setintfreq: procedure(info: Pointer; int_freq: cfloat); cdecl;

//----------------------------------------------------------
// Section 11: Format support
//----------------------------------------------------------

var
  // Check if format is supported
  ay_format_supported: function(filePath: PAYChar): TAYBool; cdecl;

//----------------------------------------------------------
// Section 12: Empty song handling
//----------------------------------------------------------

var
  // Initialize empty song
  ay_initemptysong: function(sr: cuint32; callback: TAYEmptyCallback): Pointer; cdecl;

  // Set AY write callback
  ay_setaywritecallback: procedure(info: Pointer; callback: TAYWriteCallback); cdecl;

//----------------------------------------------------------
// Section 13: Utility functions
//----------------------------------------------------------

var
  // Check if Turbo Sound mode
  ay_ists: function(info: Pointer): TAYBool; cdecl;

  // Get song sample rate
  ay_getsamplerate: function(info: Pointer): cuint32; cdecl;

  // Set song sample rate
  ay_setsamplerate: procedure(info: Pointer; sr: cuint32); cdecl;

  // Get oversample factor
  ay_getoversample: function(info: Pointer): cuint32; cdecl;

  // Set oversample factor
  ay_setoversample: procedure(info: Pointer; factor: cuint32); cdecl;

  // Get chip type (0 = AY, 1 = YM)
  ay_getchiptype: function(info: Pointer): Byte; cdecl;

  // Set chip type (0 = AY, 1 = YM)
  ay_setchiptype: procedure(info: Pointer; chip_type: Byte); cdecl;

implementation

function AyflyLoad(const LibraryName: string): Boolean;
begin
  AyflyUnload;
  LibAyflyHandle := LoadLibrary(LibraryName);
  if LibAyflyHandle = NilHandle then Exit(False);

  // Load all functions
  pointer(ay_initsong) := GetProcedureAddress(LibAyflyHandle, 'ay_initsong');
  pointer(ay_initsongindirect) := GetProcedureAddress(LibAyflyHandle, 'ay_initsongindirect');
  pointer(ay_getsonginfo) := GetProcedureAddress(LibAyflyHandle, 'ay_getsonginfo');
  pointer(ay_getsonginfoindirect) := GetProcedureAddress(LibAyflyHandle, 'ay_getsonginfoindirect');
  pointer(ay_getsongname) := GetProcedureAddress(LibAyflyHandle, 'ay_getsongname');
  pointer(ay_getsongauthor) := GetProcedureAddress(LibAyflyHandle, 'ay_getsongauthor');
  pointer(ay_getsongpath) := GetProcedureAddress(LibAyflyHandle, 'ay_getsongpath');
  pointer(ay_startsong) := GetProcedureAddress(LibAyflyHandle, 'ay_startsong');
  pointer(ay_stopsong) := GetProcedureAddress(LibAyflyHandle, 'ay_stopsong');
  pointer(ay_resetsong) := GetProcedureAddress(LibAyflyHandle, 'ay_resetsong');
  pointer(ay_seeksong) := GetProcedureAddress(LibAyflyHandle, 'ay_seeksong');
  pointer(ay_closesong) := GetProcedureAddress(LibAyflyHandle, 'ay_closesong');
  pointer(ay_songstarted) := GetProcedureAddress(LibAyflyHandle, 'ay_songstarted');
  pointer(ay_getsonglength) := GetProcedureAddress(LibAyflyHandle, 'ay_getsonglength');
  pointer(ay_getelapsedtime) := GetProcedureAddress(LibAyflyHandle, 'ay_getelapsedtime');
  pointer(ay_getsongloop) := GetProcedureAddress(LibAyflyHandle, 'ay_getsongloop');
  pointer(ay_setvolume) := GetProcedureAddress(LibAyflyHandle, 'ay_setvolume');
  pointer(ay_getvolume) := GetProcedureAddress(LibAyflyHandle, 'ay_getvolume');
  pointer(ay_chnlmute) := GetProcedureAddress(LibAyflyHandle, 'ay_chnlmute');
  pointer(ay_chnlmuted) := GetProcedureAddress(LibAyflyHandle, 'ay_chnlmuted');
  pointer(ay_setmixtype) := GetProcedureAddress(LibAyflyHandle, 'ay_setmixtype');
  pointer(ay_getmixtype) := GetProcedureAddress(LibAyflyHandle, 'ay_getmixtype');
  pointer(ay_setelapsedcallback) := GetProcedureAddress(LibAyflyHandle, 'ay_setelapsedcallback');
  pointer(ay_setstoppedcallback) := GetProcedureAddress(LibAyflyHandle, 'ay_setstoppedcallback');
  pointer(ay_rendersongbuffer) := GetProcedureAddress(LibAyflyHandle, 'ay_rendersongbuffer');
  pointer(ay_getregs) := GetProcedureAddress(LibAyflyHandle, 'ay_getregs');
  pointer(ay_getz80freq) := GetProcedureAddress(LibAyflyHandle, 'ay_getz80freq');
  pointer(ay_setz80freq) := GetProcedureAddress(LibAyflyHandle, 'ay_setz80freq');
  pointer(ay_getayfreq) := GetProcedureAddress(LibAyflyHandle, 'ay_getayfreq');
  pointer(ay_setayfreq) := GetProcedureAddress(LibAyflyHandle, 'ay_setayfreq');
  pointer(ay_getintfreq) := GetProcedureAddress(LibAyflyHandle, 'ay_getintfreq');
  pointer(ay_setintfreq) := GetProcedureAddress(LibAyflyHandle, 'ay_setintfreq');
  pointer(ay_format_supported) := GetProcedureAddress(LibAyflyHandle, 'ay_format_supported');
  pointer(ay_initemptysong) := GetProcedureAddress(LibAyflyHandle, 'ay_initemptysong');
  pointer(ay_setaywritecallback) := GetProcedureAddress(LibAyflyHandle, 'ay_setaywritecallback');
  pointer(ay_ists) := GetProcedureAddress(LibAyflyHandle, 'ay_ists');
  pointer(ay_getsamplerate) := GetProcedureAddress(LibAyflyHandle, 'ay_getsamplerate');
  pointer(ay_setsamplerate) := GetProcedureAddress(LibAyflyHandle, 'ay_setsamplerate');
  pointer(ay_getoversample) := GetProcedureAddress(LibAyflyHandle, 'ay_getoversample');
  pointer(ay_setoversample) := GetProcedureAddress(LibAyflyHandle, 'ay_setoversample');
  pointer(ay_getchiptype) := GetProcedureAddress(LibAyflyHandle, 'ay_getchiptype');
  pointer(ay_setchiptype) := GetProcedureAddress(LibAyflyHandle, 'ay_setchiptype');

  Result := True;
end;

procedure AyflyUnload;
begin
  if LibAyflyHandle <> NilHandle then
  begin
    FreeLibrary(LibAyflyHandle);
    LibAyflyHandle := NilHandle;
  end;
end;

function AyflyIsLoaded: Boolean;
begin
  Result := LibAyflyHandle <> NilHandle;
end;

end.
