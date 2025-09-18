unit libstsoundlibrary;


(*
  project : Free Pascal header for libStSoundLibrary
  author  : TRon
  date    : nov 2024
  -------------------------------------------------------------------
  name    : libStSoundLibrary
  author  : Arnaud Carré
  repo    : https://github.com/arnaud-carre/StSound
  rev     : d1876bc137ab4a3852fc72076a0cdbff704a43be
*)

{$mode objfpc}{$h+}
{$packrecords c}

interface

uses
  ctypes;

const
  {$ifdef linux}
  library_name = 'libStSoundLibrary.so.1.0.0';
  {$endif}
  {$ifdef windows}
  library_name = 'libStSoundLibrary.dll';
  {$endif}
///////////////////////////////////////////////////////////////////////////////
// YmTypes.h

type
  //-----------------------------------------------------------
  // Platform specific stuff
  //-----------------------------------------------------------
  Tyms8   = cint8;        //  8 bits signed integer
  Tyms16  = cint16;       // 16 bits signed integer
  Tyms32  = cint32;       // 32 bits signed integer

  Tymu8   = cuint8;       //  8 bits unsigned integer
  Tymu16  = cuint16;      // 16 bits unsigned integer
  Tymu32  = cuint32;      // 32 bits unsigned integer

  Tymint  = Tyms32;       // Native "int" for speed purpose. StSound suppose int is signed and at least 32bits. If not, change it to match to yms32
  Pymchar = pchar;        // ymchar is 8 bits char character (used for null terminated strings)

  //-----------------------------------------------------------
  // Multi-platform
  //-----------------------------------------------------------
//  Tymbool   = cint;       // boolean ( theorically nothing is assumed for its size in StSound,so keep using int)
//  #define  YMFALSE (0)
//  #define  YMTRUE  (!YMFALSE)

  Tymbool   = Boolean32;  // boolean ( theorically nothing is assumed for its size in StSound,so keep using int)
  Tymsample = Tyms16;     // StSound emulator render mono 16bits signed PCM samples
  Pymsample = ^Tymsample;


///////////////////////////////////////////////////////////////////////////////

type
  PYMMUSIC = ^TYMMUSIC;
  TYMMUSIC = record end;

  PymMusicInfo = ^TymMusicInfo;
  TymMusicInfo = record
    pSongName      : pymchar;
    pSongAuthor    : pymchar;
    pSongComment   : pymchar;
    pSongType      : pymchar;
    pSongPlayer    : pymchar;
    musicTimeInSec : tyms32;    // keep for compatibility
    musicTimeInMs  : tyms32;
  end;

var
  // Create object
  ymMusicCreate          : function (): PYMMUSIC; cdecl;
  ymMusicCreateWithRate  : function (rate: Tymint): PYMMUSIC; cdecl;

  // Release object
  ymMusicDestroy         : procedure(pMusic: PYMMUSIC); cdecl;

  // Global settings
  ymMusicSetLowpassFiler : procedure(pMus: PYMMUSIC; bActive: Tymbool); cdecl;

  // Functions
  ymMusicLoad            : function (pMusic: PYMMUSIC; const fName: pchar): Tymbool; cdecl;                   // Method 1 : Load file using stdio library (fopen/fread, etc..)
  ymMusicLoadMemory      : function (pMusic: PYMMUSIC; pBlock: pointer; size: Tymu32): Tymbool; cdecl;        // Method 2 : Load file from a memory block

  ymMusicCompute         : function (pMusic: PYMMUSIC; pBuffer: Pymsample; nbSample: Tymint): Tymbool; cdecl; // Render nbSample samples of current YM tune into pBuffer PCM 16bits mono sample buffer.

  ymMusicSetLoopMode     : procedure(pMusic: PYMMUSIC; bLoop: Tymbool); cdecl;
  ymMusicGetLastError    : function (pMusic: PYMMUSIC): pchar; cdecl;
  ymMusicGetRegister     : function (pMusic: PYMMUSIC; reg: Tymint): cint; cdecl;
  ymMusicGetInfo         : procedure(pMusic: PYMMUSIC; pInfo: PymMusicInfo); cdecl;
  ymMusicPlay            : procedure(pMusic: PYMMUSIC); cdecl;
  ymMusicPause           : procedure(pMusic: PYMMUSIC); cdecl;
  ymMusicStop            : procedure(pMusic: PYMMUSIC); cdecl;
  ymMusicIsOver          : function (_pMus:  PYMMUSIC): Tymbool; cdecl;

  ymMusicRestart         : procedure(pMusic: PYMMUSIC); cdecl;

  ymMusicIsSeekable      : function (pMusic: PYMMUSIC): tymbool; cdecl;
  ymMusicGetPos          : function (pMusic: PYMMUSIC): Tymu32; cdecl;
  ymMusicSeek            : procedure(pMusic: PYMMUSIC; timeInMs: Tymu32); cdecl;

  procedure LoadLib(const aLibName: string);

implementation

uses
  sysutils, dynlibs;

var
  library_handle: TLibHandle;


function FindLibName(aLibName: string): string;
var
  PathNames : array of string = ('.', '.lib', 'lib');
  PathName  : string;
begin
  for PathName in PathNames do
    if FileExists(PathName + '/' + aLibName) then
    begin
      FindLibName := PathName + '/' + aLibName;
      exit;
    end;

  FindLibName := aLibName;
end;

procedure LoadLibFn(var fn_var; const fn_name: string);
begin
  pointer(fn_var) := GetProcedureAddress(library_handle, fn_name);
end;

procedure LoadLib(const aLibName: string);
begin
  library_handle := LoadLibrary(aLibName);

  if library_handle = NilHandle then
  begin
    writeln(GetLoadErrorStr);
    runError(2);
  end;

  // Create object
  LoadLibFn(ymMusicCreate          , 'ymMusicCreate'          );
  LoadLibFn(ymMusicCreateWithRate  , 'ymMusicCreateWithRate'  );

  // Release object
  LoadLibFn(ymMusicDestroy         , 'ymMusicDestroy'         );

  // Global settings
  LoadLibFn(ymMusicSetLowpassFiler , 'ymMusicSetLowpassFiler' );

  // Functions
  LoadLibFn(ymMusicLoad            , 'ymMusicLoad'            );
  LoadLibFn(ymMusicLoadMemory      , 'ymMusicLoadMemory'      );

  LoadLibFn(ymMusicCompute         , 'ymMusicCompute'         );

  LoadLibFn(ymMusicSetLoopMode     , 'ymMusicSetLoopMode'     );
  LoadLibFn(ymMusicGetLastError    , 'ymMusicGetLastError'    );
  LoadLibFn(ymMusicGetRegister     , 'ymMusicGetRegister'     );
  LoadLibFn(ymMusicGetInfo         , 'ymMusicGetInfo'         );
  LoadLibFn(ymMusicPlay            , 'ymMusicPlay'            );
  LoadLibFn(ymMusicPause           , 'ymMusicPause'           );
  LoadLibFn(ymMusicStop            , 'ymMusicStop'            );
  LoadLibFn(ymMusicIsOver          , 'ymMusicIsOver'          );

  LoadLibFn(ymMusicRestart         , 'ymMusicRestart'         );

  LoadLibFn(ymMusicIsSeekable      , 'ymMusicIsSeekable'      );
  LoadLibFn(ymMusicGetPos          , 'ymMusicGetPos'          );
  LoadLibFn(ymMusicSeek            , 'ymMusicSeek'            );
end;


initialization
 // LoadLib(FindLibName(library_name));
end.
