unit profile_service;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  Contnrs,
  launcher_models;

procedure ExportProfile(const AFileName: string; AProfile: TProfile);
function ImportProfile(const AFileName, ABaseDirectory: string; AEngines, AAvailableWads: TObjectList; AUnresolved: TStrings): TProfile;

implementation

uses
  IniFiles,
  path_service,
  SysUtils;

procedure WriteStoredPath(AIni: TCustomIniFile; const APrefix: string; const APath: TStoredPath);
begin
  AIni.WriteString('Profile', APrefix + 'Path', APath.Value);
  AIni.WriteBool('Profile', APrefix + 'Absolute', APath.IsAbsolute);
end;

function ReadStoredPath(AIni: TCustomIniFile; const APrefix: string): TStoredPath;
begin
  Result.Value := AIni.ReadString('Profile', APrefix + 'Path', '');
  Result.IsAbsolute := AIni.ReadBool('Profile', APrefix + 'Absolute', False);
end;

procedure ExportProfile(const AFileName: string; AProfile: TProfile);
var
  Index: Integer;
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(AFileName);
  try
    Ini.Clear;
    Ini.WriteInteger('Profile', 'FormatVersion', 1);
    Ini.WriteString('Profile', 'Name', AProfile.Name);
    WriteStoredPath(Ini, 'Engine', AProfile.EnginePath);
    WriteStoredPath(Ini, 'IWad', AProfile.IWadPath);
    Ini.WriteString('Profile', 'ExtraArguments', AProfile.ExtraArguments);
    Ini.WriteInteger('Profile', 'Skill', AProfile.Options.Skill);
    Ini.WriteString('Profile', 'StartMap', AProfile.Options.StartMap);
    Ini.WriteBool('Profile', 'NoMonsters', AProfile.Options.NoMonsters);
    Ini.WriteBool('Profile', 'FastMonsters', AProfile.Options.FastMonsters);
    Ini.WriteBool('Profile', 'RespawnMonsters', AProfile.Options.RespawnMonsters);
    Ini.WriteBool('Profile', 'Multiplayer', AProfile.Options.EnableMultiplayer);
    Ini.WriteBool('Profile', 'HostGame', AProfile.Options.HostGame);
    Ini.WriteString('Profile', 'HostName', AProfile.Options.HostName);
    Ini.WriteInteger('Profile', 'Port', AProfile.Options.Port);
    Ini.WriteInteger('Profile', 'PlayerCount', AProfile.Options.PlayerCount);
    Ini.WriteInteger('Profile', 'ModCount', AProfile.Mods.Count);
    for Index := 0 to AProfile.Mods.Count - 1 do begin
      Ini.WriteString('Profile', 'Mod' + IntToStr(Index) + 'Path', AProfile.Mods[Index]);
      Ini.WriteBool('Profile', 'Mod' + IntToStr(Index) + 'Absolute', PtrInt(AProfile.Mods.Objects[Index]) <> 0);
    end;
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function FindEngineByFileName(const ABaseDirectory, AFileName: string; AEngines: TObjectList; out APath: TStoredPath): Boolean;
var
  Engine: TEngine;
  FoundCount: Integer;
  Index: Integer;
begin
  FoundCount := 0;
  for Index := 0 to AEngines.Count - 1 do begin
    Engine := TEngine(AEngines[Index]);
    if SameText(ExtractFileName(ResolveStoredPath(ABaseDirectory, Engine.FileName)), AFileName) then begin
      Inc(FoundCount);
      APath := Engine.FileName;
    end;
  end;
  Result := FoundCount = 1;
end;

function FindWadByFileName(const ABaseDirectory, AFileName: string; AWads: TObjectList; out APath: TStoredPath): Boolean;
var
  FoundCount: Integer;
  Index: Integer;
  Wad: TWadMetadata;
begin
  FoundCount := 0;
  for Index := 0 to AWads.Count - 1 do begin
    Wad := TWadMetadata(AWads[Index]);
    if SameText(ExtractFileName(ResolveStoredPath(ABaseDirectory, Wad.FileName)), AFileName) then begin
      Inc(FoundCount);
      APath := Wad.FileName;
    end;
  end;
  Result := FoundCount = 1;
end;

function ResolveImportedPath(
    const ABaseDirectory: string;
    const AImported: TStoredPath;
    AIsEngine: Boolean;
    AEngines, AWads: TObjectList;
    out AResolved: TStoredPath
): Boolean;
var
  AbsolutePath: string;
begin
  AResolved := AImported;
  AbsolutePath := ResolveStoredPath(ABaseDirectory, AImported);
  if FileExists(AbsolutePath) then
    Exit(True);
  if AIsEngine then
    Result := FindEngineByFileName(ABaseDirectory, ExtractFileName(AImported.Value), AEngines, AResolved)
  else
    Result := FindWadByFileName(ABaseDirectory, ExtractFileName(AImported.Value), AWads, AResolved);
end;

function ImportProfile(const AFileName, ABaseDirectory: string; AEngines, AAvailableWads: TObjectList; AUnresolved: TStrings): TProfile;
var
  ImportedPath: TStoredPath;
  Index: Integer;
  Ini: TMemIniFile;
  ModCount: Integer;
  ResolvedPath: TStoredPath;
begin
  Result := nil;
  Ini := TMemIniFile.Create(AFileName, [ifoStripQuotes]);
  try
    try
      if Ini.ReadInteger('Profile', 'FormatVersion', 0) <> 1 then
        raise EConvertError.Create('Unsupported profile format.');
      Result := TProfile.Create;
      Result.Name := Ini.ReadString('Profile', 'Name', 'Imported Profile');
      Result.Locked := False;

      ImportedPath := ReadStoredPath(Ini, 'Engine');
      if ResolveImportedPath(ABaseDirectory, ImportedPath, True, AEngines, AAvailableWads, ResolvedPath) then
        Result.EnginePath := ResolvedPath
      else begin
        Result.EnginePath := ImportedPath;
        AUnresolved.Add('Engine: ' + ImportedPath.Value);
      end;

      ImportedPath := ReadStoredPath(Ini, 'IWad');
      if ResolveImportedPath(ABaseDirectory, ImportedPath, False, AEngines, AAvailableWads, ResolvedPath) then
        Result.IWadPath := ResolvedPath
      else begin
        Result.IWadPath := ImportedPath;
        AUnresolved.Add('IWAD: ' + ImportedPath.Value);
      end;

      Result.ExtraArguments := Ini.ReadString('Profile', 'ExtraArguments', '');
      Result.Options := DefaultLaunchOptions;
      Result.Options.Skill := Ini.ReadInteger('Profile', 'Skill', 3);
      Result.Options.StartMap := Ini.ReadString('Profile', 'StartMap', '');
      Result.Options.NoMonsters := Ini.ReadBool('Profile', 'NoMonsters', False);
      Result.Options.FastMonsters := Ini.ReadBool('Profile', 'FastMonsters', False);
      Result.Options.RespawnMonsters := Ini.ReadBool('Profile', 'RespawnMonsters', False);
      Result.Options.EnableMultiplayer := Ini.ReadBool('Profile', 'Multiplayer', False);
      Result.Options.HostGame := Ini.ReadBool('Profile', 'HostGame', False);
      Result.Options.HostName := Ini.ReadString('Profile', 'HostName', '');
      Result.Options.Port := Ini.ReadInteger('Profile', 'Port', 10666);
      Result.Options.PlayerCount := Ini.ReadInteger('Profile', 'PlayerCount', 4);

      ModCount := Ini.ReadInteger('Profile', 'ModCount', 0);
      if (ModCount < 0) or (ModCount > 100000) then
        raise EConvertError.Create('Invalid profile mod count.');
      for Index := 0 to ModCount - 1 do begin
        ImportedPath.Value := Ini.ReadString('Profile', 'Mod' + IntToStr(Index) + 'Path', '');
        ImportedPath.IsAbsolute := Ini.ReadBool('Profile', 'Mod' + IntToStr(Index) + 'Absolute', False);
        if ResolveImportedPath(ABaseDirectory, ImportedPath, False, AEngines, AAvailableWads, ResolvedPath) then
          Result.Mods.AddObject(ResolvedPath.Value, TObject(PtrInt(Ord(ResolvedPath.IsAbsolute))))
        else begin
          Result.Mods.AddObject(ImportedPath.Value, TObject(PtrInt(Ord(ImportedPath.IsAbsolute))));
          AUnresolved.Add('Mod: ' + ImportedPath.Value);
        end;
      end;
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    Ini.Free;
  end;
end;

end.
