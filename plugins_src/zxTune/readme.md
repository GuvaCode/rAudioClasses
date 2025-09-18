# ZxTune Pascal Header

Music for ZX Spectrum in chiptune format, supporting tracker formats such as:  
Chip Tracker v1.xx, Digital Music Maker, Digital Studio AY/Covox, Extreme Tracker v1.xx,  
ProDigiTracker v0.xx, SQ Digital Tracker, Sample Tracker.

## Project Basis
This project is based on ZXTune version "zxtune-r4310". Regarding Z80 emulation, the project includes most of the original source code, including third-party dependencies. Other third-party emulators (etc.) have been removed (since I already have separate standalone players or don't need them), and I didn't want this player to be larger than necessary (e.g., FLAC, mp3, ogg, sidplayfp, vorbis, xmp support removed). Some unused "boosting" components were also removed, along with RAR support.

## Added New Functions
```pascal
ZXTune_GetCurrentPosition: function(player: ZXTuneHandle): NativeUInt; cdecl;
ZXTune_GetDuration: function(player: ZXTuneHandle): LongInt; cdecl;


