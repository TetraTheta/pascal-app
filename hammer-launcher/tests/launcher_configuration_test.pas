program launcher_configuration_test;

{$mode objfpc}{$H+}

uses
  IniFiles, SysUtils, launcher_configuration;

var
  Configuration: TLauncherConfiguration;
  ConfigurationFile: TIniFile;
  ConfigurationPath: string;
  ExecutablePath: string;
begin
  ExecutablePath := GetTempFileName(GetTempDir(False), 'hlt');
  ConfigurationPath := ChangeFileExt(ExecutablePath, '.ini');
  DeleteFile(ExecutablePath);
  DeleteFile(ConfigurationPath);
  try
    Configuration := LoadLauncherConfiguration(ExecutablePath);
    Assert(FileExists(ConfigurationPath));
    Assert(Configuration.HL2Hammer = '');
    Assert(Configuration.HL2HammerPP = '');
    Assert(Configuration.GModHammer = '');
    Assert(Configuration.GModHammerPP = '');
    Assert(Configuration.EZ2Hammer = '');
    Assert(Configuration.EZ2HammerPP = '');

    ConfigurationFile := TIniFile.Create(ConfigurationPath);
    try
      ConfigurationFile.WriteString('hl2', 'hammer', 'C:\hammer.exe');
      ConfigurationFile.WriteString('gmod', 'hammer++', 'C:\hammerplusplus.exe');
      ConfigurationFile.UpdateFile;
    finally
      ConfigurationFile.Free;
    end;

    Configuration := LoadLauncherConfiguration(ExecutablePath);
    Assert(Configuration.HL2Hammer = 'C:\hammer.exe');
    Assert(Configuration.GModHammerPP = 'C:\hammerplusplus.exe');
  finally
    DeleteFile(ConfigurationPath);
  end;
end.
