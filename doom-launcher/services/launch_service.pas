unit launch_service;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  launcher_models;

function BuildLaunchArguments(const ABaseDirectory, ASaveDirectory: string; AProfile: TProfile): TStringList;
function LaunchProfile(const ABaseDirectory: string; AProfile: TProfile; out AError: string): Boolean;
function ParseWindowsArguments(const AArguments: string): TStringList;
function ValidateLaunchOptions(const AOptions: TLaunchOptions; out AError: string): Boolean;

implementation

uses
  path_service,
  Process,
  SysUtils;

function ParseWindowsArguments(const AArguments: string): TStringList;
var
  Argument: string;
  BackslashCount: Integer;
  CharacterIndex: Integer;
  InQuotes: Boolean;
begin
  Result := TStringList.Create;
  CharacterIndex := 1;
  try
    while CharacterIndex <= Length(AArguments) do begin
      while (CharacterIndex <= Length(AArguments)) and (AArguments[CharacterIndex] in [' ', #9]) do
        Inc(CharacterIndex);
      if CharacterIndex > Length(AArguments) then
        Break;

      Argument := '';
      InQuotes := False;
      while CharacterIndex <= Length(AArguments) do begin
        if (not InQuotes) and (AArguments[CharacterIndex] in [' ', #9]) then
          Break;

        BackslashCount := 0;
        while (CharacterIndex <= Length(AArguments)) and (AArguments[CharacterIndex] = '\') do begin
          Inc(BackslashCount);
          Inc(CharacterIndex);
        end;

        if (CharacterIndex <= Length(AArguments)) and (AArguments[CharacterIndex] = '"') then begin
          Argument := Argument + StringOfChar('\', BackslashCount div 2);
          if Odd(BackslashCount) then
            Argument := Argument + '"'
          else
            InQuotes := not InQuotes;
          Inc(CharacterIndex);
        end
        else begin
          Argument := Argument + StringOfChar('\', BackslashCount);
          if CharacterIndex <= Length(AArguments) then begin
            Argument := Argument + AArguments[CharacterIndex];
            Inc(CharacterIndex);
          end;
        end;
      end;

      if InQuotes then
        raise EConvertError.Create('Extra arguments contain an unmatched quote.');
      Result.Add(Argument);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function ValidateLaunchOptions(const AOptions: TLaunchOptions; out AError: string): Boolean;
begin
  AError := '';
  if (AOptions.Skill < 0) or (AOptions.Skill > 5) then
    AError := 'Skill must be between 0 and 5.'
  else if AOptions.EnableMultiplayer and ((AOptions.Port < 1) or (AOptions.Port > 65535)) then
    AError := 'Port must be between 1 and 65535.'
  else if AOptions.EnableMultiplayer and AOptions.HostGame and ((AOptions.PlayerCount < 1) or (AOptions.PlayerCount > 64)) then
    AError := 'Player count must be between 1 and 64.'
  else if AOptions.EnableMultiplayer and (not AOptions.HostGame) and (Trim(AOptions.HostName) = '') then
    AError := 'A host name or IP address is required.';
  Result := AError = '';
end;

function BuildLaunchArguments(const ABaseDirectory, ASaveDirectory: string; AProfile: TProfile): TStringList;
var
  ErrorText: string;
  ExtraArguments: TStringList;
  Index: Integer;
  ModPath: TStoredPath;
begin
  if not ValidateLaunchOptions(AProfile.Options, ErrorText) then
    raise EConvertError.Create(ErrorText);

  Result := TStringList.Create;
  try
    Result.Add('-iwad');
    Result.Add(ResolveStoredPath(ABaseDirectory, AProfile.IWadPath));
    if AProfile.Mods.Count > 0 then begin
      Result.Add('-file');
      for Index := 0 to AProfile.Mods.Count - 1 do begin
        ModPath := StoredPath(AProfile.Mods[Index], PtrInt(AProfile.Mods.Objects[Index]) <> 0);
        Result.Add(ResolveStoredPath(ABaseDirectory, ModPath));
      end;
    end;
    Result.Add('-savedir');
    Result.Add(ExpandFileName(ASaveDirectory));

    if Trim(AProfile.Options.StartMap) <> '' then begin
      if AProfile.Options.Skill > 0 then begin
        Result.Add('-skill');
        Result.Add(IntToStr(AProfile.Options.Skill));
      end;
      Result.Add('+map');
      Result.Add(Trim(AProfile.Options.StartMap));
    end;
    if AProfile.Options.NoMonsters then
      Result.Add('-nomonsters');
    if AProfile.Options.FastMonsters then
      Result.Add('-fast');
    if AProfile.Options.RespawnMonsters then
      Result.Add('-respawn');
    if AProfile.Options.EnableMultiplayer then begin
      Result.Add('-net');
      if AProfile.Options.HostGame then begin
        Result.Add('-host');
        Result.Add(IntToStr(AProfile.Options.PlayerCount));
        Result.Add('-port');
        Result.Add(IntToStr(AProfile.Options.Port));
      end
      else begin
        Result.Add('-join');
        Result.Add(Trim(AProfile.Options.HostName) + ':' + IntToStr(AProfile.Options.Port));
      end;
    end;

    ExtraArguments := ParseWindowsArguments(AProfile.ExtraArguments);
    try
      Result.AddStrings(ExtraArguments);
    finally
      ExtraArguments.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function LaunchProfile(const ABaseDirectory: string; AProfile: TProfile; out AError: string): Boolean;
var
  Arguments: TStringList;
  EnginePath: string;
  Index: Integer;
  IWadPath: string;
  ModPath: TStoredPath;
  Process: TProcess;
  SaveDirectory: string;
begin
  Result := False;
  AError := '';
  EnginePath := ResolveStoredPath(ABaseDirectory, AProfile.EnginePath);
  IWadPath := ResolveStoredPath(ABaseDirectory, AProfile.IWadPath);
  if not FileExists(EnginePath) then
    AError := 'The selected engine does not exist.'
  else if not FileExists(IWadPath) then
    AError := 'The selected IWAD does not exist.';
  if AError <> '' then
    Exit;

  for Index := 0 to AProfile.Mods.Count - 1 do begin
    ModPath := StoredPath(AProfile.Mods[Index], PtrInt(AProfile.Mods.Objects[Index]) <> 0);
    if not FileExists(ResolveStoredPath(ABaseDirectory, ModPath)) then begin
      AError := 'A selected mod does not exist: ' + ModPath.Value;
      Exit;
    end;
  end;

  SaveDirectory := IncludeTrailingPathDelimiter(ABaseDirectory) + 'saves' + DirectorySeparator + SanitizeDirectoryName(AProfile.Name);
  if not ForceDirectories(SaveDirectory) then begin
    AError := 'Unable to create the save directory.';
    Exit;
  end;

  try
    Arguments := BuildLaunchArguments(ABaseDirectory, SaveDirectory, AProfile);
    try
      Process := TProcess.Create(nil);
      try
        Process.Executable := EnginePath;
        Process.CurrentDirectory := ExtractFileDir(EnginePath);
        Process.Parameters.Assign(Arguments);
        Process.Execute;
        Result := True;
      finally
        Process.Free;
      end;
    finally
      Arguments.Free;
    end;
  except
    on E: Exception do
      AError := E.Message;
  end;
end;

end.
