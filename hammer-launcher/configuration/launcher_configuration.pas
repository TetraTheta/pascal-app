unit launcher_configuration;

{$mode objfpc}{$H+}

interface

type
  TLauncherConfiguration = record
    HL2Hammer: string;
    HL2HammerPP: string;
    GModHammer: string;
    GModHammerPP: string;
    EZ2Hammer: string;
    EZ2HammerPP: string;
  end;

function LoadLauncherConfiguration(const AExecutablePath: string): TLauncherConfiguration;

implementation

uses
  IniFiles, SysUtils;

function LoadLauncherConfiguration(const AExecutablePath: string): TLauncherConfiguration;
var
  ConfigurationExists: Boolean;
  ConfigurationFile: TIniFile;
  ConfigurationPath: string;
begin
  ConfigurationPath := ChangeFileExt(AExecutablePath, '.ini');
  ConfigurationExists := FileExists(ConfigurationPath);
  ConfigurationFile := TIniFile.Create(ConfigurationPath);
  try
    if not ConfigurationExists then
    begin
      ConfigurationFile.WriteString('hl2', 'hammer', '');
      ConfigurationFile.WriteString('hl2', 'hammer++', '');
      ConfigurationFile.WriteString('gmod', 'hammer', '');
      ConfigurationFile.WriteString('gmod', 'hammer++', '');
      ConfigurationFile.WriteString('ez2', 'hammer', '');
      ConfigurationFile.WriteString('ez2', 'hammer++', '');
      ConfigurationFile.UpdateFile;
    end;

    Result.HL2Hammer := ConfigurationFile.ReadString('hl2', 'hammer', '');
    Result.HL2HammerPP := ConfigurationFile.ReadString('hl2', 'hammer++', '');
    Result.GModHammer := ConfigurationFile.ReadString('gmod', 'hammer', '');
    Result.GModHammerPP := ConfigurationFile.ReadString('gmod', 'hammer++', '');
    Result.EZ2Hammer := ConfigurationFile.ReadString('ez2', 'hammer', '');
    Result.EZ2HammerPP := ConfigurationFile.ReadString('ez2', 'hammer++', '');
  finally
    ConfigurationFile.Free;
  end;
end;

end.
