unit launcher_configuration;

{$MODE objfpc}
{$H+}

interface

uses
  launcher_models;

function BackupBrokenConfiguration(const AFileName: string): string;
function FindLauncherConfiguration(const AExecutablePath: string; const AArguments: array of string): string;
function LoadLauncherSettings(const AFileName: string; ASettings: TLauncherSettings; out AError: string): Boolean;
procedure SaveLauncherSettings(const AFileName: string; ASettings: TLauncherSettings);

implementation

uses
  Classes,
  IniFiles,
  SysUtils;

const
  CurrentFormatVersion = 1;
  CurrentWadCacheVersion = 2;
  MaximumItemCount = 100000;

function FindLauncherConfiguration(const AExecutablePath: string; const AArguments: array of string): string;
var
  Index: Integer;
begin
  Result := ChangeFileExt(AExecutablePath, '.ini');
  for Index := Low(AArguments) to High(AArguments) - 1 do
    if SameText(AArguments[Index], '-ini') and (AArguments[Index + 1] <> '') then begin
      Result := ExpandFileName(AArguments[Index + 1]);
      Exit;
    end;
end;

function IndexedSection(const APrefix: string; AIndex: Integer): string;
begin
  Result := APrefix + '.' + IntToStr(AIndex);
end;

function ReadCount(AIni: TCustomIniFile; const ASection, AKey: string): Integer;
begin
  Result := AIni.ReadInteger(ASection, AKey, 0);
  if (Result < 0) or (Result > MaximumItemCount) then
    raise EConvertError.CreateFmt('Invalid item count in [%s].', [ASection]);
end;

function ReadStoredPath(AIni: TCustomIniFile; const ASection, APrefix: string): TStoredPath;
begin
  Result.Value := AIni.ReadString(ASection, APrefix + 'Path', '');
  Result.IsAbsolute := AIni.ReadBool(ASection, APrefix + 'Absolute', False);
end;

procedure WriteStoredPath(AIni: TCustomIniFile; const ASection, APrefix: string; const APath: TStoredPath);
begin
  AIni.WriteString(ASection, APrefix + 'Path', APath.Value);
  AIni.WriteBool(ASection, APrefix + 'Absolute', APath.IsAbsolute);
end;

procedure ReadLaunchOptions(AIni: TCustomIniFile; const ASection: string; out AOptions: TLaunchOptions);
begin
  AOptions := DefaultLaunchOptions;
  AOptions.EnableMultiplayer := AIni.ReadBool(ASection, 'Multiplayer', False);
  AOptions.FastMonsters := AIni.ReadBool(ASection, 'FastMonsters', False);
  AOptions.HostGame := AIni.ReadBool(ASection, 'HostGame', False);
  AOptions.HostName := AIni.ReadString(ASection, 'HostName', '');
  AOptions.NoMonsters := AIni.ReadBool(ASection, 'NoMonsters', False);
  AOptions.PlayerCount := AIni.ReadInteger(ASection, 'PlayerCount', 4);
  AOptions.Port := AIni.ReadInteger(ASection, 'Port', 10666);
  AOptions.RespawnMonsters := AIni.ReadBool(ASection, 'RespawnMonsters', False);
  AOptions.Skill := AIni.ReadInteger(ASection, 'Skill', 3);
  AOptions.StartMap := AIni.ReadString(ASection, 'StartMap', '');
end;

procedure WriteLaunchOptions(AIni: TCustomIniFile; const ASection: string; const AOptions: TLaunchOptions);
begin
  AIni.WriteBool(ASection, 'Multiplayer', AOptions.EnableMultiplayer);
  AIni.WriteBool(ASection, 'FastMonsters', AOptions.FastMonsters);
  AIni.WriteBool(ASection, 'HostGame', AOptions.HostGame);
  AIni.WriteString(ASection, 'HostName', AOptions.HostName);
  AIni.WriteBool(ASection, 'NoMonsters', AOptions.NoMonsters);
  AIni.WriteInteger(ASection, 'PlayerCount', AOptions.PlayerCount);
  AIni.WriteInteger(ASection, 'Port', AOptions.Port);
  AIni.WriteBool(ASection, 'RespawnMonsters', AOptions.RespawnMonsters);
  AIni.WriteInteger(ASection, 'Skill', AOptions.Skill);
  AIni.WriteString(ASection, 'StartMap', AOptions.StartMap);
end;

function LoadLauncherSettings(const AFileName: string; ASettings: TLauncherSettings; out AError: string): Boolean;
var
  Count: Integer;
  DataDirectory: TDataDirectory;
  Engine: TEngine;
  Index: Integer;
  Ini: TMemIniFile;
  ModIndex: Integer;
  Profile: TProfile;
  Section: string;
  Wad: TWadMetadata;
begin
  Result := False;
  AError := '';
  if not FileExists(AFileName) then
    Exit(True);

  Ini := TMemIniFile.Create(AFileName, [ifoStripQuotes]);
  try
    try
      if Ini.ReadInteger('Application', 'FormatVersion', CurrentFormatVersion) <> CurrentFormatVersion then
        raise EConvertError.Create('Unsupported configuration format.');

      ASettings.ExitAfterLaunch := Ini.ReadBool('Application', 'ExitAfterLaunch', False);
      ASettings.SelectedProfileIndex := Ini.ReadInteger('Application', 'SelectedProfile', -1);

      Count := ReadCount(Ini, 'Engines', 'Count');
      for Index := 0 to Count - 1 do begin
        Section := IndexedSection('Engine', Index);
        Engine := TEngine.Create(Ini.ReadString(Section, 'Name', ''), ReadStoredPath(Ini, Section, ''));
        ASettings.Engines.Add(Engine);
      end;

      Count := ReadCount(Ini, 'DataDirectories', 'Count');
      for Index := 0 to Count - 1 do begin
        Section := IndexedSection('DataDirectory', Index);
        DataDirectory := TDataDirectory.Create(Ini.ReadString(Section, 'Name', ''), ReadStoredPath(Ini, Section, ''), False);
        ASettings.DataDirectories.Add(DataDirectory);
      end;

      Count := ReadCount(Ini, 'Profiles', 'Count');
      for Index := 0 to Count - 1 do begin
        Section := IndexedSection('Profile', Index);
        Profile := TProfile.Create;
        try
          Profile.Name := Ini.ReadString(Section, 'Name', '');
          Profile.Locked := Ini.ReadBool(Section, 'Locked', False);
          Profile.EnginePath := ReadStoredPath(Ini, Section, 'Engine');
          Profile.IWadPath := ReadStoredPath(Ini, Section, 'IWad');
          Profile.ExtraArguments := Ini.ReadString(Section, 'ExtraArguments', '');
          ReadLaunchOptions(Ini, Section, Profile.Options);
          Count := ReadCount(Ini, Section, 'ModCount');
          for ModIndex := 0 to Count - 1 do
            Profile.Mods.AddObject(
                Ini.ReadString(Section, 'Mod' + IntToStr(ModIndex) + 'Path', ''),
                TObject(PtrInt(Ord(Ini.ReadBool(Section, 'Mod' + IntToStr(ModIndex) + 'Absolute', False))))
            );
          ASettings.Profiles.Add(Profile);
          Profile := nil;
        finally
          Profile.Free;
        end;
      end;

      if ASettings.SelectedProfileIndex >= ASettings.Profiles.Count then
        ASettings.SelectedProfileIndex := -1;

      if Ini.ReadInteger('WadCache', 'Version', 0) = CurrentWadCacheVersion then begin
        Count := ReadCount(Ini, 'WadCache', 'Count');
        for Index := 0 to Count - 1 do begin
          Section := IndexedSection('WadCache', Index);
          Wad := TWadMetadata.Create;
          try
            Wad.FileName := ReadStoredPath(Ini, Section, '');
            Wad.FileSize := Ini.ReadInt64(Section, 'Size', -1);
            Wad.ModifiedAt := Ini.ReadDateTime(Section, 'ModifiedAt', 0);
            Wad.IsIWad := Ini.ReadBool(Section, 'IsIWad', False);
            Wad.HasMaps := Ini.ReadBool(Section, 'HasMaps', False);
            Wad.MapIds.CommaText := Ini.ReadString(Section, 'Maps', '');
            ASettings.WadCache.Add(Wad);
            Wad := nil;
          finally
            Wad.Free;
          end;
        end;
      end;
      Result := True;
    except
      on E: Exception do begin
        ASettings.DataDirectories.Clear;
        ASettings.Engines.Clear;
        ASettings.Profiles.Clear;
        ASettings.WadCache.Clear;
        ASettings.ExitAfterLaunch := False;
        ASettings.SelectedProfileIndex := -1;
        AError := E.Message;
      end;
    end;
  finally
    Ini.Free;
  end;
end;

procedure WriteSettings(AIni: TCustomIniFile; ASettings: TLauncherSettings);
var
  DataDirectory: TDataDirectory;
  Engine: TEngine;
  Index: Integer;
  ModIndex: Integer;
  Profile: TProfile;
  Section: string;
  Wad: TWadMetadata;
begin
  AIni.WriteInteger('Application', 'FormatVersion', CurrentFormatVersion);
  AIni.WriteBool('Application', 'ExitAfterLaunch', ASettings.ExitAfterLaunch);
  AIni.WriteInteger('Application', 'SelectedProfile', ASettings.SelectedProfileIndex);

  AIni.WriteInteger('Engines', 'Count', ASettings.Engines.Count);
  for Index := 0 to ASettings.Engines.Count - 1 do begin
    Engine := TEngine(ASettings.Engines[Index]);
    Section := IndexedSection('Engine', Index);
    AIni.WriteString(Section, 'Name', Engine.DisplayName);
    WriteStoredPath(AIni, Section, '', Engine.FileName);
  end;

  AIni.WriteInteger('DataDirectories', 'Count', ASettings.DataDirectories.Count);
  for Index := 0 to ASettings.DataDirectories.Count - 1 do begin
    DataDirectory := TDataDirectory(ASettings.DataDirectories[Index]);
    Section := IndexedSection('DataDirectory', Index);
    AIni.WriteString(Section, 'Name', DataDirectory.DisplayName);
    WriteStoredPath(AIni, Section, '', DataDirectory.DirectoryName);
  end;

  AIni.WriteInteger('Profiles', 'Count', ASettings.Profiles.Count);
  for Index := 0 to ASettings.Profiles.Count - 1 do begin
    Profile := TProfile(ASettings.Profiles[Index]);
    Section := IndexedSection('Profile', Index);
    AIni.WriteString(Section, 'Name', Profile.Name);
    AIni.WriteBool(Section, 'Locked', Profile.Locked);
    WriteStoredPath(AIni, Section, 'Engine', Profile.EnginePath);
    WriteStoredPath(AIni, Section, 'IWad', Profile.IWadPath);
    AIni.WriteString(Section, 'ExtraArguments', Profile.ExtraArguments);
    WriteLaunchOptions(AIni, Section, Profile.Options);
    AIni.WriteInteger(Section, 'ModCount', Profile.Mods.Count);
    for ModIndex := 0 to Profile.Mods.Count - 1 do begin
      AIni.WriteString(Section, 'Mod' + IntToStr(ModIndex) + 'Path', Profile.Mods[ModIndex]);
      AIni.WriteBool(Section, 'Mod' + IntToStr(ModIndex) + 'Absolute', PtrInt(Profile.Mods.Objects[ModIndex]) <> 0);
    end;
  end;

  AIni.WriteInteger('WadCache', 'Version', CurrentWadCacheVersion);
  AIni.WriteInteger('WadCache', 'Count', ASettings.WadCache.Count);
  for Index := 0 to ASettings.WadCache.Count - 1 do begin
    Wad := TWadMetadata(ASettings.WadCache[Index]);
    Section := IndexedSection('WadCache', Index);
    WriteStoredPath(AIni, Section, '', Wad.FileName);
    AIni.WriteInt64(Section, 'Size', Wad.FileSize);
    AIni.WriteDateTime(Section, 'ModifiedAt', Wad.ModifiedAt);
    AIni.WriteBool(Section, 'IsIWad', Wad.IsIWad);
    AIni.WriteBool(Section, 'HasMaps', Wad.HasMaps);
    AIni.WriteString(Section, 'Maps', Wad.MapIds.CommaText);
  end;
end;

procedure SaveLauncherSettings(const AFileName: string; ASettings: TLauncherSettings);
var
  BackupFileName: string;
  Ini: TMemIniFile;
  TemporaryFileName: string;
begin
  TemporaryFileName := AFileName + '.tmp';
  SysUtils.DeleteFile(TemporaryFileName);
  Ini := TMemIniFile.Create(TemporaryFileName);
  try
    WriteSettings(Ini, ASettings);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  if FileExists(AFileName) then begin
    BackupFileName := AFileName + '.replace-backup';
    SysUtils.DeleteFile(BackupFileName);
    if not RenameFile(AFileName, BackupFileName) then begin
      SysUtils.DeleteFile(TemporaryFileName);
      raise EFCreateError.CreateFmt('Unable to replace %s.', [AFileName]);
    end;
    if not RenameFile(TemporaryFileName, AFileName) then begin
      RenameFile(BackupFileName, AFileName);
      SysUtils.DeleteFile(TemporaryFileName);
      raise EFCreateError.CreateFmt('Unable to replace %s.', [AFileName]);
    end;
    SysUtils.DeleteFile(BackupFileName);
  end
  else if not RenameFile(TemporaryFileName, AFileName) then begin
    SysUtils.DeleteFile(TemporaryFileName);
    raise EFCreateError.CreateFmt('Unable to create %s.', [AFileName]);
  end;
end;

function BackupBrokenConfiguration(const AFileName: string): string;
begin
  Result := AFileName + '.broken-' + FormatDateTime('yyyymmdd-hhnnss', Now);
  if not RenameFile(AFileName, Result) then
    raise EFCreateError.CreateFmt('Unable to back up %s.', [AFileName]);
end;

end.
