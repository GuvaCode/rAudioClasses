unit libasap;

{$mode objfpc}{$h+}
{$packrecords c}

interface

uses
  SysUtils, dynlibs;

const
  {$IFDEF MSWINDOWS}
  DEFAULT_LIB_NAME = 'libasap.dll';
  {$ELSE}
  {$IFDEF DARWIN}
  DEFAULT_LIB_NAME = 'libasap.dylib';
  {$ELSE}
  DEFAULT_LIB_NAME = 'libasap.so';
  {$ENDIF}
  {$ENDIF}

type
  TPoly9LookupArray = array[0..510] of Byte;
  TPoly17LookupArray = array[0..16384] of Byte;
  TSincLookupArray = array[0..1023, 0..31] of SmallInt;

  NmiStatus = (NmiStatus_RESET, NmiStatus_ON_V_BLANK,NmiStatus_WAS_V_BLANK);

  PASAPWriter = ^ASAPWriter;
  ASAPWriter = record
       output :PInt16;
       outputOffset : Integer;
       outputEnd: Integer;
  end;

  ASAPModuleType = (amtUnknown, amtType1, amtType2,ASAPModuleType_SAP_B,
        ASAPModuleType_SAP_C,
        ASAPModuleType_SAP_D,
        ASAPModuleType_SAP_S,
        ASAPModuleType_CMC,
        ASAPModuleType_CM3,
        ASAPModuleType_CMR,
        ASAPModuleType_CMS,
        ASAPModuleType_DLT,
        ASAPModuleType_MPT,
        ASAPModuleType_RMT,
        ASAPModuleType_TMC,
        ASAPModuleType_TM2,
        ASAPModuleType_FC);
  //   sample formats
  ASAPSampleFormat = (
    ASAPSampleFormat_U8,   // Unsigned 8-bit
    ASAPSampleFormat_S16_L_E, // Signed 16-bit little-endian
    ASAPSampleFormat_S16_B_E // Signed 16-bit big-endian
    );

 TPokeyChannel = record
    Audf: Integer;
    Audc: Integer;
    PeriodCycles: Integer;
    TickCycle: Integer;
    TimerCycle: Integer;
    Mute: Integer;
    Out: Integer;
    Delta: Integer;
  end;

  TPokeyChannelArray = array[0..3] of TPokeyChannel;

  TPokey = record
    Channels: TPokeyChannelArray;
    Audctl: Integer;
    Skctl: Integer;
    Irqst: Integer;
    Init: Boolean;
    DivCycles: Integer;
    ReloadCycles1: Integer;
    ReloadCycles3: Integer;
    PolyIndex: Integer;
    DeltaBufferLength: Integer;
    DeltaBuffer: PInteger; // Correspond à un pointeur sur int en C c'est sure !!
    SumDACInputs: Integer;
    SumDACOutputs: Integer;
    IIRRate: Integer;
    IIRAcc: Integer;
    Trailing: Integer;
  end;

  PokeyPair = record
    Poly9Lookup: TPoly9LookupArray;
    Poly17Lookup: TPoly17LookupArray;
    ExtraPokeyMask: Integer;
    BasePokey: TPokey;
    ExtraPokey: TPokey;
    SampleRate: Integer;
    SincLookup: TSincLookupArray;
    SampleFactor: Integer;
    SampleOffset: Integer;
    ReadySamplesStart: Integer;
    ReadySamplesEnd: Integer;
  end;

  PASAP = ^ASAP;
  TCpu6502 = ^Cpu6502;
  Cpu6502 = record
    asap:  PASAP;
    memory: array[0..65535] of Byte;
    cycle: Integer;
    pc: Integer;
    a: Integer;
    x: Integer;
    y: Integer;
    s: Integer;
    nz: Integer;
    c: Integer;
    vdi: Integer;
  end;

  PASAPInfo = ^ASAPInfo;
  ASAPInfo = record
    filename: PChar;
    author: PChar;
    title: PChar;
    date: PChar;
    channels: Integer;
    songs: Integer;
    defaultSong: Integer;
    durations: array[0..31] of Integer;
    loops: array[0..31] of Boolean;
    ntsc: Boolean;
    mtype_: ASAPModuleType;
    fastplay: Integer;
    music: Integer;
    init: Integer;
    player: Integer;
    covoxAddr: Integer;
    headerLen: Integer;
    songPos: array[0..31] of Byte;
  end;

  ASAP = record
    nextEventCycle: Integer;
    cpu: TCpu6502;
    nextScanlineCycle: Integer;
    nmist: NmiStatus;
    consol: Integer;
    covox: array[0..3] of Byte;
    pokeys: PokeyPair;
    moduleInfo: ASAPInfo;
    nextPlayerCycle: Integer;
    tmcPerFrameCounter: Integer;
    currentSong: Integer;
    currentDuration: Integer;
    blocksPlayed: Integer;
    silenceCycles: Integer;
    silenceCyclesCounter: Integer;
    gtiaOrCovoxPlayedThisFrame: Boolean;
    currentSampleRate: Integer;
  end;


const
  ASAP_SAMPLE_RATE = 44100;
  ASAPInfo_VERSION_MAJOR = 6;
  ASAPInfo_VERSION_MINOR = 0;
  ASAPInfo_VERSION_MICRO = 3;
  ASAPInfo_VERSION = '6.0.3';
  ASAPInfo_YEARS = '2005-2025';
  ASAPInfo_CREDITS = 'Another Slight Atari Player (C) 2005-2025 Piotr Fusik'#10+
                     'CMC, MPT, TMC, TM2 players (C) 1994-2005 Marcin Lewandowski'#10+
                     'RMT player (C) 2002-2005 Radek Sterba'#10+
                     'DLT player (C) 2009 Marek Konopka'#10+
                     'CMS player (C) 1999 David Spilka'#10+
                     'FC player (C) 2011 Jerzy Kut'#10;
  ASAPInfo_COPYRIGHT = 'This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.';
  ASAPInfo_MAX_MODULE_LENGTH = 65000;
  ASAPInfo_MAX_TEXT_LENGTH = 127;
  ASAPInfo_MAX_SONGS = 32;
  ASAPWriter_MAX_SAVE_EXTS = 3;
  ASAPWriter_MAX_DURATION_LENGTH = 9;

var
  // ASAP functions
  ASAP_New: function: PASAP; cdecl;
  ASAP_Delete: procedure(self: PASAP); cdecl;
  ASAP_GetSampleRate: function(const self: PASAP): Integer; cdecl;
  ASAP_SetSampleRate: procedure(self: PASAP; sampleRate: Integer); cdecl;
  ASAP_DetectSilence: procedure(self: PASAP; seconds: Integer); cdecl;
  ASAP_Load: function(self: PASAP; filename: PChar; const module: PByte; moduleLen: Integer): Boolean; cdecl;
  ASAP_GetInfo: function(const self: PASAP): PASAPInfo; cdecl;
  ASAP_MutePokeyChannels: procedure(self: PASAP; mask: Integer); cdecl;
  ASAP_PlaySong: function(self: PASAP; song: Integer; duration: Integer): Boolean; cdecl;
  ASAP_GetBlocksPlayed: function(const self: PASAP): Integer; cdecl;
  ASAP_GetPosition: function(const self: PASAP): Integer; cdecl;
  ASAP_SeekSample: function(self: PASAP; block: Integer): Boolean; cdecl;
  ASAP_Seek: function(self: PASAP; position: Integer): Boolean; cdecl;
  ASAP_GetWavHeader: function(self: PASAP; buffer: PByte; format: ASAPSampleFormat; metadata: Boolean): Integer; cdecl;
  ASAP_Generate: function(self: PASAP; buffer: PByte; bufferLen: Integer; format: ASAPSampleFormat): Integer; cdecl;
  ASAP_GetPokeyChannelVolume: function(const self: PASAP; channel: Integer): Integer; cdecl;

  // ASAPInfo functions
  ASAPInfo_New: function: PASAPInfo; cdecl;
  ASAPInfo_Delete: procedure(self: PASAPInfo); cdecl;
  ASAPInfo_ParseDuration: function(s: PAnsiChar): Integer; cdecl;
  ASAPInfo_IsOurFile: function(filename: PAnsiChar): Boolean; cdecl;
  ASAPInfo_IsOurExt: function(ext: PAnsiChar): Boolean; cdecl;
  ASAPInfo_Load: function(self: PASAPInfo; filename: PAnsiChar; const module: PByte; moduleLen: Integer): Boolean; cdecl;
  ASAPInfo_GetAuthor: function(const self: PASAPInfo): PAnsiChar; cdecl;
  ASAPInfo_SetAuthor: function(self: PASAPInfo; value: PAnsiChar): Boolean; cdecl;
  ASAPInfo_GetTitle: function(const self: PASAPInfo): PAnsiChar; cdecl;
  ASAPInfo_SetTitle: function(self: PASAPInfo; value: PAnsiChar): Boolean; cdecl;
  ASAPInfo_GetTitleOrFilename: function(const self: PASAPInfo): PAnsiChar; cdecl;
  ASAPInfo_GetDate: function(const self: PASAPInfo): PAnsiChar; cdecl;
  ASAPInfo_SetDate: function(self: PASAPInfo; value: PAnsiChar): Boolean; cdecl;
  ASAPInfo_GetYear: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetMonth: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetDayOfMonth: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetChannels: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetSongs: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetDefaultSong: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_SetDefaultSong: function(self: PASAPInfo; song: Integer): Boolean; cdecl;
  ASAPInfo_GetDuration: function(const self: PASAPInfo; song: Integer): Integer; cdecl;
  ASAPInfo_SetDuration: function(self: PASAPInfo; song: Integer; duration: Integer): Boolean; cdecl;
  ASAPInfo_GetLoop: function(const self: PASAPInfo; song: Integer): Boolean; cdecl;
  ASAPInfo_SetLoop: function(self: PASAPInfo; song: Integer; loop: Boolean): Boolean; cdecl;
  ASAPInfo_IsNtsc: function(const self: PASAPInfo): Boolean; cdecl;
  ASAPInfo_CanSetNtsc: function(const self: PASAPInfo): Boolean; cdecl;
  ASAPInfo_SetNtsc: procedure(self: PASAPInfo; ntsc: Boolean); cdecl;
  ASAPInfo_GetTypeLetter: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetPlayerRateScanlines: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetPlayerRateHz: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetMusicAddress: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_SetMusicAddress: function(self: PASAPInfo; address: Integer): Boolean; cdecl;
  ASAPInfo_GetInitAddress: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetPlayerAddress: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetCovoxAddress: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetSapHeaderLength: function(const self: PASAPInfo): Integer; cdecl;
  ASAPInfo_GetInstrumentNamesOffset: function(const self: PASAPInfo; const module: PByte; moduleLen: Integer): Integer; cdecl;
  ASAPInfo_GetExtDescription: function(ext: PAnsiChar): PAnsiChar; cdecl;
  ASAPInfo_GetOriginalModuleExt: function(const self: PASAPInfo; const module: PByte; moduleLen: Integer): PAnsiChar; cdecl;

  // ASAPWriter functions
  ASAPWriter_New: function: PASAPWriter; cdecl;
  ASAPWriter_Delete: procedure(self: PASAPWriter); cdecl;
  ASAPWriter_GetSaveExts: function(exts: PPAnsiChar; const info: PASAPInfo; const module: PByte; moduleLen: Integer): Integer; cdecl;
  ASAPWriter_DurationToString: function(result: PByte; value: Integer): Integer; cdecl;
  ASAPWriter_SetOutput: procedure(self: PASAPWriter; output: PByte; startIndex: Integer; endIndex: Integer); cdecl;
  ASAPWriter_Write: function(self: PASAPWriter; targetFilename: PAnsiChar; const info: PASAPInfo; const module: PByte; moduleLen: Integer; tag: Boolean): Integer; cdecl;

  // Флаг загрузки библиотеки
  ASAPLibraryLoaded: Boolean = False;

procedure LoadASAPLibrary(const LibraryName: string = DEFAULT_LIB_NAME);
function ASAPLoaded: Boolean;

implementation

var
  library_handle: TLibHandle = NilHandle;

procedure LoadProc(var fn_var; const fn_name: string);
var
  proc: Pointer;
begin
  proc := GetProcedureAddress(library_handle, fn_name);
  if proc = nil then
    raise Exception.CreateFmt('Procedure "%s" not found in ASAP library', [fn_name]);
  pointer(fn_var) := proc;
end;

procedure LoadASAPLibrary(const LibraryName: string);
begin
  if library_handle <> NilHandle then
    Exit; // Уже загружена

  library_handle := LoadLibrary(LibraryName);
  if library_handle = NilHandle then
    raise Exception.CreateFmt('Could not load library "%s"', [LibraryName]);

  try
    // ASAP functions
    LoadProc(ASAP_New, 'ASAP_New');
    LoadProc(ASAP_Delete, 'ASAP_Delete');
    LoadProc(ASAP_GetSampleRate, 'ASAP_GetSampleRate');
    LoadProc(ASAP_SetSampleRate, 'ASAP_SetSampleRate');
    LoadProc(ASAP_DetectSilence, 'ASAP_DetectSilence');
    LoadProc(ASAP_Load, 'ASAP_Load');
    LoadProc(ASAP_GetInfo, 'ASAP_GetInfo');
    LoadProc(ASAP_MutePokeyChannels, 'ASAP_MutePokeyChannels');
    LoadProc(ASAP_PlaySong, 'ASAP_PlaySong');
    LoadProc(ASAP_GetBlocksPlayed, 'ASAP_GetBlocksPlayed');
    LoadProc(ASAP_GetPosition, 'ASAP_GetPosition');
    LoadProc(ASAP_SeekSample, 'ASAP_SeekSample');
    LoadProc(ASAP_Seek, 'ASAP_Seek');
    LoadProc(ASAP_GetWavHeader, 'ASAP_GetWavHeader');
    LoadProc(ASAP_Generate, 'ASAP_Generate');
    LoadProc(ASAP_GetPokeyChannelVolume, 'ASAP_GetPokeyChannelVolume');

    // ASAPInfo functions
    LoadProc(ASAPInfo_New, 'ASAPInfo_New');
    LoadProc(ASAPInfo_Delete, 'ASAPInfo_Delete');
    LoadProc(ASAPInfo_ParseDuration, 'ASAPInfo_ParseDuration');
    LoadProc(ASAPInfo_IsOurFile, 'ASAPInfo_IsOurFile');
    LoadProc(ASAPInfo_IsOurExt, 'ASAPInfo_IsOurExt');
    LoadProc(ASAPInfo_Load, 'ASAPInfo_Load');
    LoadProc(ASAPInfo_GetAuthor, 'ASAPInfo_GetAuthor');
    LoadProc(ASAPInfo_SetAuthor, 'ASAPInfo_SetAuthor');
    LoadProc(ASAPInfo_GetTitle, 'ASAPInfo_GetTitle');
    LoadProc(ASAPInfo_SetTitle, 'ASAPInfo_SetTitle');
    LoadProc(ASAPInfo_GetTitleOrFilename, 'ASAPInfo_GetTitleOrFilename');
    LoadProc(ASAPInfo_GetDate, 'ASAPInfo_GetDate');
    LoadProc(ASAPInfo_SetDate, 'ASAPInfo_SetDate');
    LoadProc(ASAPInfo_GetYear, 'ASAPInfo_GetYear');
    LoadProc(ASAPInfo_GetMonth, 'ASAPInfo_GetMonth');
    LoadProc(ASAPInfo_GetDayOfMonth, 'ASAPInfo_GetDayOfMonth');
    LoadProc(ASAPInfo_GetChannels, 'ASAPInfo_GetChannels');
    LoadProc(ASAPInfo_GetSongs, 'ASAPInfo_GetSongs');
    LoadProc(ASAPInfo_GetDefaultSong, 'ASAPInfo_GetDefaultSong');
    LoadProc(ASAPInfo_SetDefaultSong, 'ASAPInfo_SetDefaultSong');
    LoadProc(ASAPInfo_GetDuration, 'ASAPInfo_GetDuration');
    LoadProc(ASAPInfo_SetDuration, 'ASAPInfo_SetDuration');
    LoadProc(ASAPInfo_GetLoop, 'ASAPInfo_GetLoop');
    LoadProc(ASAPInfo_SetLoop, 'ASAPInfo_SetLoop');
    LoadProc(ASAPInfo_IsNtsc, 'ASAPInfo_IsNtsc');
    LoadProc(ASAPInfo_CanSetNtsc, 'ASAPInfo_CanSetNtsc');
    LoadProc(ASAPInfo_SetNtsc, 'ASAPInfo_SetNtsc');
    LoadProc(ASAPInfo_GetTypeLetter, 'ASAPInfo_GetTypeLetter');
    LoadProc(ASAPInfo_GetPlayerRateScanlines, 'ASAPInfo_GetPlayerRateScanlines');
    LoadProc(ASAPInfo_GetPlayerRateHz, 'ASAPInfo_GetPlayerRateHz');
    LoadProc(ASAPInfo_GetMusicAddress, 'ASAPInfo_GetMusicAddress');
    LoadProc(ASAPInfo_SetMusicAddress, 'ASAPInfo_SetMusicAddress');
    LoadProc(ASAPInfo_GetInitAddress, 'ASAPInfo_GetInitAddress');
    LoadProc(ASAPInfo_GetPlayerAddress, 'ASAPInfo_GetPlayerAddress');
    LoadProc(ASAPInfo_GetCovoxAddress, 'ASAPInfo_GetCovoxAddress');
    LoadProc(ASAPInfo_GetSapHeaderLength, 'ASAPInfo_GetSapHeaderLength');
    LoadProc(ASAPInfo_GetInstrumentNamesOffset, 'ASAPInfo_GetInstrumentNamesOffset');
    LoadProc(ASAPInfo_GetExtDescription, 'ASAPInfo_GetExtDescription');
    LoadProc(ASAPInfo_GetOriginalModuleExt, 'ASAPInfo_GetOriginalModuleExt');

    // ASAPWriter functions
    LoadProc(ASAPWriter_New, 'ASAPWriter_New');
    LoadProc(ASAPWriter_Delete, 'ASAPWriter_Delete');
    LoadProc(ASAPWriter_GetSaveExts, 'ASAPWriter_GetSaveExts');
    LoadProc(ASAPWriter_DurationToString, 'ASAPWriter_DurationToString');
    LoadProc(ASAPWriter_SetOutput, 'ASAPWriter_SetOutput');
    LoadProc(ASAPWriter_Write, 'ASAPWriter_Write');

    ASAPLibraryLoaded := True;

  except
    on E: Exception do
    begin
      UnloadLibrary(library_handle);
      library_handle := NilHandle;
      ASAPLibraryLoaded := False;
      raise Exception.CreateFmt('Error loading ASAP library: %s', [E.Message]);
    end;
  end;
end;

function ASAPLoaded: Boolean;
begin
  Result := ASAPLibraryLoaded;
end;

initialization

finalization
{  if library_handle <> NilHandle then
  begin
    UnloadLibrary(library_handle);
    library_handle := NilHandle;
    ASAPLibraryLoaded := False;
  end; }
end.
