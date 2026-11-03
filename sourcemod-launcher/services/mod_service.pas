unit mod_service;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  SysUtils,
  Contnrs,
  Process;

type
  TSourceMod = class
  public
    Title: string;
    Directory: string;
    IconFile: string;
  end;

{ Returns the registered Steam installation, or an empty string. }
function FindSteamDirectory: string;
{ Scans only direct sourcemods children; AMods owns the returned objects. }
procedure DiscoverMods(const ASteamDirectory: string; AMods: TObjectList; out ASdkDirectory: string; out AFailures: Integer);
{ Exposed separately so arguments can be verified without starting a game. }
procedure ConfigureLaunch(AProcess: TProcess; const ASdkDirectory, AModDirectory: string);

implementation

uses
  Registry,
  Windows,
  keyvalues;

function FindSteamDirectory: string;
const
  Keys: array[0..1] of string = ('Software\Valve\Steam', 'Software\WOW6432Node\Valve\Steam');
var
  Reg: TRegistry;
  Root, K: Integer;
  ValueName: string;
begin
  Result := '';
  Reg := TRegistry.Create(KEY_READ);
  try
    for Root := 0 to 1 do begin
      if Root = 0 then
        Reg.RootKey := HKEY_CURRENT_USER
      else
        Reg.RootKey := HKEY_LOCAL_MACHINE;
      for K := Low(Keys) to High(Keys) do begin
        if not Reg.OpenKeyReadOnly(Keys[K]) then
          Continue;
        try
          if Root = 0 then
            ValueName := 'SteamPath'
          else
            ValueName := 'InstallPath';
          if Reg.ValueExists(ValueName) then begin
            Result := StringReplace(Reg.ReadString(ValueName), '/', PathDelim, [rfReplaceAll]);
            if DirectoryExists(Result) then
              Exit;
          end;
        finally
          Reg.CloseKey;
        end;
      end;
    end;
    Result := '';
  finally
    Reg.Free;
  end;
end;

function CompareMods(AFirst, ASecond: Pointer): Integer;
begin
  Result := CompareText(TSourceMod(AFirst).Title, TSourceMod(ASecond).Title);
  if Result = 0 then
    Result := CompareText(TSourceMod(AFirst).Directory, TSourceMod(ASecond).Directory);
end;

procedure DiscoverMods(const ASteamDirectory: string; AMods: TObjectList; out ASdkDirectory: string; out AFailures: Integer);
var
  Libraries: TStringList;
  Tree, Node, Entry, Info, FileSystem: TKeyValue;
  I, J: Integer;
  SteamApps, FileName, Candidate, ModDirectory, Icon: string;
  Search: TSearchRec;
  SourceMod: TSourceMod;

  procedure AddLibrary(const APath: string);
  var
    Normalized: string;
  begin
    if APath = '' then
      Exit;
    Normalized := ExcludeTrailingPathDelimiter(ExpandFileName(StringReplace(APath, '/', PathDelim, [rfReplaceAll])));
    if Libraries.IndexOf(Normalized) < 0 then
      Libraries.Add(Normalized);
  end;

begin
  ASdkDirectory := '';
  AFailures := 0;
  AMods.Clear;
  if ASteamDirectory = '' then
    Exit;
  Libraries := TStringList.Create;
  try
    Libraries.CaseSensitive := False;
    AddLibrary(ASteamDirectory);
    FileName := IncludeTrailingPathDelimiter(ASteamDirectory) + 'steamapps\libraryfolders.vdf';
    if FileExists(FileName) then
      try
        Tree := ReadKeyValues(FileName);
        try
          Node := Tree.Child('libraryfolders');
          if not Assigned(Node) then
            raise EConvertError.Create('Missing libraryfolders block.');
          for I := 0 to Node.Children.Count - 1 do begin
            Entry := TKeyValue(Node.Children[I]);
            if not TryStrToInt(Entry.Name, J) then
              Continue;
            if Entry.Children.Count > 0 then
              AddLibrary(Entry.Text('path'))
            else
              AddLibrary(Entry.Value);
          end;
        finally
          Tree.Free;
        end;
      except
        on E: Exception do
          Inc(AFailures);
      end;
    for I := 0 to Libraries.Count - 1 do begin
      SteamApps := IncludeTrailingPathDelimiter(Libraries[I]) + 'steamapps\';
      FileName := SteamApps + 'appmanifest_243730.acf';
      if (ASdkDirectory = '') and FileExists(FileName) then
        try
          Tree := ReadKeyValues(FileName);
          try
            Node := Tree.Child('AppState');
            if not Assigned(Node) then
              raise EConvertError.Create('Missing AppState block.');
            if (Node.Text('appid') = '243730') and (Node.Text('installdir') <> '') then begin
              Candidate := ExpandFileName(SteamApps + 'common\' + Node.Text('installdir'));
              if FileExists(IncludeTrailingPathDelimiter(Candidate) + 'hl2.exe') then
                ASdkDirectory := Candidate;
            end;
          finally
            Tree.Free;
          end;
        except
          on E: Exception do
            Inc(AFailures);
        end;
      if FindFirst(SteamApps + 'sourcemods\*', faDirectory, Search) = 0 then
        try
          repeat
            if ((Search.Attr and faDirectory) = 0) or (Search.Name = '.') or (Search.Name = '..') then
              Continue;
            ModDirectory := ExpandFileName(SteamApps + 'sourcemods\' + Search.Name);
            FileName := IncludeTrailingPathDelimiter(ModDirectory) + 'gameinfo.txt';
            if not FileExists(FileName) then
              Continue;
            try
              Tree := ReadKeyValues(FileName);
              try
                Info := Tree.Child('GameInfo');
                if not Assigned(Info) then
                  raise EConvertError.Create('Missing GameInfo block.');
                FileSystem := Info.Child('FileSystem');
                if not Assigned(FileSystem) then
                  Continue;
                if (FileSystem.Text('SteamAppId') <> '243730') or (Trim(Info.Text('mapbase_core')) = '1') then
                  Continue;
                SourceMod := TSourceMod.Create;
                try
                  SourceMod.Directory := ModDirectory;
                  SourceMod.Title := Info.Text('game');
                  if Trim(SourceMod.Title) = '' then
                    SourceMod.Title := Search.Name;
                  Icon := StringReplace(Info.Text('icon'), '/', PathDelim, [rfReplaceAll]);
                  if Icon <> '' then begin
                    Candidate := ExpandFileName(IncludeTrailingPathDelimiter(ModDirectory) + Icon + '.tga');
                    // Icon metadata must not read outside its own mod directory.
                    if SameText(Copy(Candidate, 1, Length(ModDirectory) + 1), IncludeTrailingPathDelimiter(ModDirectory)) then
                      SourceMod.IconFile := Candidate;
                  end;
                  AMods.Add(SourceMod);
                  SourceMod := nil;
                finally
                  SourceMod.Free;
                end;
              finally
                Tree.Free;
              end;
            except
              on E: Exception do
                Inc(AFailures);
            end;
          until FindNext(Search) <> 0;
        finally
          SysUtils.FindClose(Search);
        end;
    end;
    AMods.Sort(@CompareMods);
  finally
    Libraries.Free;
  end;
end;

procedure ConfigureLaunch(AProcess: TProcess; const ASdkDirectory, AModDirectory: string);
begin
  if not FileExists(IncludeTrailingPathDelimiter(ASdkDirectory) + 'hl2.exe') then
    raise EFOpenError.Create('Source SDK Base 2013 Singleplayer is not installed.');
  if not FileExists(IncludeTrailingPathDelimiter(AModDirectory) + 'gameinfo.txt') then
    raise EFOpenError.Create('The selected source mod is no longer available. Refresh the list.');
  AProcess.Executable := IncludeTrailingPathDelimiter(ASdkDirectory) + 'hl2.exe';
  AProcess.CurrentDirectory := ASdkDirectory;
  AProcess.Parameters.Clear;
  AProcess.Parameters.Add('-game');
  AProcess.Parameters.Add('sourcetest');
  AProcess.Parameters.Add('-steam');
  AProcess.Parameters.Add('-game');
  AProcess.Parameters.Add(AModDirectory);
  AProcess.Parameters.Add('+exec');
  AProcess.Parameters.Add('autoexec');
end;

end.
