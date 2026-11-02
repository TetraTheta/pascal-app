unit launcher_configuration;

{$MODE objfpc}
{$H+}

interface

type
  TLauncherSettings = record
    ExitOnLaunch: Boolean;
    LastLaunch: string;
  end;

{ Relative -ini paths are resolved against the startup working directory. }
function FindLauncherConfiguration(const AExecutable: string; const AArguments: array of string): string;
function LoadSettings(const AFileName: string): TLauncherSettings;
procedure SaveSettings(const AFileName: string; const ASettings: TLauncherSettings);

implementation

uses
  SysUtils,
  IniFiles;

function FindLauncherConfiguration(const AExecutable: string; const AArguments: array of string): string;
var
  I: Integer;
begin
  Result := ChangeFileExt(AExecutable, '.ini');
  for I := Low(AArguments) to High(AArguments) do
    if SameText(AArguments[I], '-ini') then begin
      if (I = High(AArguments)) or (AArguments[I + 1] = '') then
        raise EConvertError.Create('Expected a file path after -ini.');
      Exit(ExpandFileName(AArguments[I + 1]));
    end;
end;

function LoadSettings(const AFileName: string): TLauncherSettings;
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(AFileName);
  try
    Ini.SetBoolStringValues(True, ['true', '1']);
    Ini.SetBoolStringValues(False, ['false', '0']);
    Result.ExitOnLaunch := Ini.ReadBool('general', 'exit_on_launch', True);
    Result.LastLaunch := Ini.ReadString('general', 'last_launch', '');
  finally
    Ini.Free;
  end;
end;

procedure SaveSettings(const AFileName: string; const ASettings: TLauncherSettings);
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(AFileName);
  try
    Ini.WriteBool('general', 'exit_on_launch', ASettings.ExitOnLaunch);
    Ini.WriteString('general', 'last_launch', ASettings.LastLaunch);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

end.
