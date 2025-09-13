{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit rAudio;

{$warn 5023 off : no warning about unused units}
interface

uses
  rAudioPlayer, rAudioFileDetector, rDefaultAudioPlayer, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('rAudio', @Register);
end.
