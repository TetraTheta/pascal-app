unit launcher_configuration;

{$MODE objfpc}
{$H+}

interface

type
  TLauncherConfiguration = record
    HL2HammerStock: string;
    HL2HammerStockArgs: string;
    HL2HammerCustom: string;
    HL2HammerCustomArgs: string;
    GModHammerStock: string;
    GModHammerStockArgs: string;
    GModHammerCustom: string;
    GModHammerCustomArgs: string;
    EZ2HammerStock: string;
    EZ2HammerStockArgs: string;
    EZ2HammerCustom: string;
    EZ2HammerCustomArgs: string;
  end;

function LoadLauncherConfiguration(const AExecutablePath: string): TLauncherConfiguration;

implementation

uses
  IniFiles,
  SysUtils;

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
    if not ConfigurationExists then begin
      ConfigurationFile.WriteString('hl2', 'stock', '');
      ConfigurationFile.WriteString('hl2', 'stockargs', '');
      ConfigurationFile.WriteString('hl2', 'custom', '');
      ConfigurationFile.WriteString('hl2', 'customargs', '');
      ConfigurationFile.WriteString('gmod', 'stock', '');
      ConfigurationFile.WriteString('gmod', 'stockargs', '');
      ConfigurationFile.WriteString('gmod', 'custom', '');
      ConfigurationFile.WriteString('gmod', 'customargs', '');
      ConfigurationFile.WriteString('ez2', 'stock', '');
      ConfigurationFile.WriteString('ez2', 'stockargs', '');
      ConfigurationFile.WriteString('ez2', 'custom', '');
      ConfigurationFile.WriteString('ez2', 'customargs', '');
      ConfigurationFile.UpdateFile;
    end;

    Result.HL2HammerStock := ConfigurationFile.ReadString('hl2', 'stock', '');
    Result.HL2HammerStockArgs := ConfigurationFile.ReadString('hl2', 'stockargs', '');
    Result.HL2HammerCustom := ConfigurationFile.ReadString('hl2', 'custom', '');
    Result.HL2HammerCustomArgs := ConfigurationFile.ReadString('hl2', 'customargs', '');
    Result.GModHammerStock := ConfigurationFile.ReadString('gmod', 'stock', '');
    Result.GModHammerStockArgs := ConfigurationFile.ReadString('gmod', 'stockargs', '');
    Result.GModHammerCustom := ConfigurationFile.ReadString('gmod', 'custom', '');
    Result.GModHammerCustomArgs := ConfigurationFile.ReadString('gmod', 'customargs', '');
    Result.EZ2HammerStock := ConfigurationFile.ReadString('ez2', 'stock', '');
    Result.EZ2HammerStockArgs := ConfigurationFile.ReadString('ez2', 'stockargs', '');
    Result.EZ2HammerCustom := ConfigurationFile.ReadString('ez2', 'custom', '');
    Result.EZ2HammerCustomArgs := ConfigurationFile.ReadString('ez2', 'customargs', '');
  finally
    ConfigurationFile.Free;
  end;
end;

end.
