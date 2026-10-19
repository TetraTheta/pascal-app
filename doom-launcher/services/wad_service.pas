unit wad_service;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, launcher_models;

function AnalyzeWadFile(const ABaseDirectory, AFileName: string; AStoreAbsolute: Boolean): TWadMetadata;
function ScanWads(const ABaseDirectory: string; ASettings: TLauncherSettings; out ACacheChanged: Boolean): TObjectList;

implementation

uses
  DateUtils, path_service, StrUtils, SysUtils, zipper;

type
  TEmbeddedWadAnalyzer = class
  private
    FMetadata: TWadMetadata;
    procedure CreateStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure DoneStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
  public
    constructor Create(AMetadata: TWadMetadata);
  end;

function IsMapId(const AValue: string): Boolean;
var
  UpperValue: string;
begin
  UpperValue := UpperCase(AValue);
  Result := ((Length(UpperValue) = 5) and (Copy(UpperValue, 1, 3) = 'MAP') and
    (UpperValue[4] in ['0'..'9']) and (UpperValue[5] in ['0'..'9'])) or
    ((Length(UpperValue) = 4) and (UpperValue[1] = 'E') and
    (UpperValue[2] in ['0'..'9']) and (UpperValue[3] = 'M') and
    (UpperValue[4] in ['0'..'9']));
end;

procedure ReadFileInformation(const AFileName: string; out ASize: Int64; out AModifiedAt: TDateTime);
var
  SearchRecord: TSearchRec;
begin
  if FindFirst(AFileName, faAnyFile, SearchRecord) <> 0 then
    raise EFOpenError.CreateFmt('Unable to read %s.', [AFileName]);
  try
    ASize := SearchRecord.Size;
    AModifiedAt := FileDateToDateTime(SearchRecord.Time);
  finally
    FindClose(SearchRecord);
  end;
end;

function ReadFixedString(AStream: TStream; ALength: Integer): string;
var
  Bytes: array of Byte;
  CharacterIndex: Integer;
begin
  Bytes := nil;
  Result := '';
  SetLength(Bytes, ALength);
  if AStream.Read(Bytes[0], ALength) <> ALength then
    raise EReadError.Create('Unexpected end of file.');
  SetLength(Result, ALength);
  for CharacterIndex := 0 to ALength - 1 do
    Result[CharacterIndex + 1] := Char(Bytes[CharacterIndex]);
  Result := TrimRightSet(Result, [#0, ' ']);
end;

procedure AnalyzeWadStream(AStream: TStream; AMetadata: TWadMetadata;
  ASetArchiveType: Boolean);
var
  DirectoryOffset: LongInt;
  EntryIndex: LongInt;
  Header: string;
  LumpCount: LongInt;
  LumpName: string;
begin
  DirectoryOffset := 0;
  LumpCount := 0;
  if AStream.Size < 12 then
    raise EReadError.Create('WAD header is incomplete.');
  AStream.Position := 0;
  Header := ReadFixedString(AStream, 4);
  if (Header <> 'IWAD') and (Header <> 'PWAD') then
    raise EReadError.Create('Not a valid WAD file.');
  if ASetArchiveType then
    AMetadata.IsIWad := Header = 'IWAD';
  AStream.ReadBuffer(LumpCount, SizeOf(LumpCount));
  AStream.ReadBuffer(DirectoryOffset, SizeOf(DirectoryOffset));
  if (LumpCount < 0) or (DirectoryOffset < 12) or (Int64(DirectoryOffset) + Int64(LumpCount) * 16 > AStream.Size) then
    raise EReadError.Create('WAD directory is outside the file.');
  AStream.Position := DirectoryOffset;
  for EntryIndex := 0 to LumpCount - 1 do
  begin
    AStream.Seek(8, soCurrent);
    LumpName := UpperCase(ReadFixedString(AStream, 8));
    if IsMapId(LumpName) then
      AMetadata.MapIds.Add(LumpName);
  end;
  AMetadata.HasMaps := AMetadata.MapIds.Count > 0;
end;

procedure AnalyzeWadArchive(const AFileName: string; AMetadata: TWadMetadata);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    AnalyzeWadStream(Stream, AMetadata, True);
  finally
    Stream.Free;
  end;
end;

constructor TEmbeddedWadAnalyzer.Create(AMetadata: TWadMetadata);
begin
  inherited Create;
  FMetadata := AMetadata;
end;

procedure TEmbeddedWadAnalyzer.CreateStream(Sender: TObject;
  var AStream: TStream; AItem: TFullZipFileEntry);
begin
  AStream := TMemoryStream.Create;
end;

procedure TEmbeddedWadAnalyzer.DoneStream(Sender: TObject;
  var AStream: TStream; AItem: TFullZipFileEntry);
begin
  try
    try
      AnalyzeWadStream(AStream, FMetadata, False);
    except
      on EReadError do
        ; // A malformed embedded WAD must not hide valid maps in the PK3.
    end;
  finally
    FreeAndNil(AStream);
  end;
end;

procedure AnalyzeZipArchive(const AFileName: string; AMetadata: TWadMetadata);
var
  Analyzer: TEmbeddedWadAnalyzer;
  EmbeddedWads: TStringList;
  EntryIndex: Integer;
  EntryName: string;
  MapName: string;
  UnZipper: TUnZipper;
begin
  UnZipper := TUnZipper.Create;
  EmbeddedWads := TStringList.Create;
  Analyzer := TEmbeddedWadAnalyzer.Create(AMetadata);
  try
    UnZipper.FileName := AFileName;
    UnZipper.Examine;
    for EntryIndex := 0 to UnZipper.Entries.Count - 1 do
    begin
      EntryName := StringReplace(UnZipper.Entries[EntryIndex].ArchiveFileName, '\', '/', [rfReplaceAll]);
      MapName := UpperCase(ChangeFileExt(ExtractFileName(EntryName), ''));
      if IsMapId(MapName) and (StartsText('maps/', EntryName) or SameText(ExtractFileExt(EntryName), '.wad')) then
        AMetadata.MapIds.Add(MapName);
      if SameText(ExtractFileExt(EntryName), '.wad') then
        EmbeddedWads.Add(UnZipper.Entries[EntryIndex].ArchiveFileName);
    end;
    if EmbeddedWads.Count > 0 then
    begin
      UnZipper.OnCreateStream := @Analyzer.CreateStream;
      UnZipper.OnDoneStream := @Analyzer.DoneStream;
      UnZipper.UnZipFiles(EmbeddedWads);
    end;
    AMetadata.HasMaps := AMetadata.MapIds.Count > 0;
  finally
    Analyzer.Free;
    EmbeddedWads.Free;
    UnZipper.Free;
  end;
end;

function AnalyzeWadFile(const ABaseDirectory, AFileName: string; AStoreAbsolute: Boolean): TWadMetadata;
var
  Extension: string;
begin
  Result := TWadMetadata.Create;
  try
    Result.FileName := CreateStoredPath(ABaseDirectory, AFileName, AStoreAbsolute);
    ReadFileInformation(AFileName, Result.FileSize, Result.ModifiedAt);
    Extension := LowerCase(ExtractFileExt(AFileName));
    if Extension = '.wad' then
      AnalyzeWadArchive(AFileName, Result)
    else if (Extension = '.pk3') or (Extension = '.zip') then
      AnalyzeZipArchive(AFileName, Result)
    else
      raise EReadError.Create('Unsupported WAD file type.');
  except
    Result.Free;
    raise;
  end;
end;

function CloneMetadata(AMetadata: TWadMetadata): TWadMetadata;
begin
  Result := TWadMetadata.Create;
  Result.FileName := AMetadata.FileName;
  Result.FileSize := AMetadata.FileSize;
  Result.HasMaps := AMetadata.HasMaps;
  Result.IsIWad := AMetadata.IsIWad;
  Result.MapIds.Assign(AMetadata.MapIds);
  Result.ModifiedAt := AMetadata.ModifiedAt;
end;

function FindCachedMetadata(const ABaseDirectory, AFileName: string; ACache: TObjectList; ASize: Int64; AModifiedAt: TDateTime): TWadMetadata;
var
  Cached: TWadMetadata;
  Index: Integer;
begin
  Result := nil;
  for Index := 0 to ACache.Count - 1 do
  begin
    Cached := TWadMetadata(ACache[Index]);
    if SameFileName(ResolveStoredPath(ABaseDirectory, Cached.FileName), AFileName) and (Cached.FileSize = ASize) and (Abs(Cached.ModifiedAt - AModifiedAt) < (1 / SecsPerDay)) then
      Exit(Cached);
  end;
end;

procedure AddDirectoryWads(const ABaseDirectory, APath: string; ADirectory: TDataDirectory; ACache, AResults: TObjectList; ASeen: TStrings; var ACacheChanged: Boolean);
var
  AbsoluteFileName: string;
  Cached: TWadMetadata;
  Extension: string;
  Metadata: TWadMetadata;
  ModifiedAt: TDateTime;
  SearchRecord: TSearchRec;
  Size: Int64;
  StoreAbsolute: Boolean;
begin
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, SearchRecord) <> 0 then
    Exit;
  try
    repeat
      if (SearchRecord.Attr and faDirectory <> 0) then
      begin
        if (SearchRecord.Name <> '.') and (SearchRecord.Name <> '..') and (SearchRecord.Attr and faSymLink = 0) then
          AddDirectoryWads(ABaseDirectory, IncludeTrailingPathDelimiter(APath) + SearchRecord.Name, ADirectory, ACache, AResults, ASeen, ACacheChanged);
      end
      else
      begin
        Extension := LowerCase(ExtractFileExt(SearchRecord.Name));
        if (Extension = '.wad') or (Extension = '.pk3') or (Extension = '.zip') then
        begin
          AbsoluteFileName := ExpandFileName(IncludeTrailingPathDelimiter(APath) + SearchRecord.Name);
          if ASeen.IndexOf(AbsoluteFileName) < 0 then
          begin
            ASeen.Add(AbsoluteFileName);
            ReadFileInformation(AbsoluteFileName, Size, ModifiedAt);
            Cached := FindCachedMetadata(ABaseDirectory, AbsoluteFileName, ACache, Size, ModifiedAt);
            if Cached <> nil then
              AResults.Add(CloneMetadata(Cached))
            else
            begin
              StoreAbsolute := ADirectory.StoreDiscoveredPathsAbsolute or not CanStoreRelative(ABaseDirectory, AbsoluteFileName);
              try
                Metadata := AnalyzeWadFile(ABaseDirectory, AbsoluteFileName, StoreAbsolute);
                AResults.Add(Metadata);
                ACache.Add(CloneMetadata(Metadata));
                ACacheChanged := True;
              except
                on E: Exception do
                  ; // Unreadable archives are ignored and can be retried on refresh.
              end;
            end;
          end;
        end;
      end;
    until FindNext(SearchRecord) <> 0;
  finally
    FindClose(SearchRecord);
  end;
end;

procedure AddEnvironmentDirectories(AList: TObjectList);
var
  DirectoryName: string;
  Index: Integer;
  Paths: TStringList;
begin
  Paths := TStringList.Create;
  try
    Paths.Delimiter := PathSeparator;
    Paths.StrictDelimiter := True;
    Paths.DelimitedText := GetEnvironmentVariable('DOOMWADPATH');
    DirectoryName := GetEnvironmentVariable('DOOMWADDIR');
    if DirectoryName <> '' then
      Paths.Insert(0, DirectoryName);
    for Index := 0 to Paths.Count - 1 do
      if Trim(Paths[Index]) <> '' then
      begin
        AList.Add(TDataDirectory.Create('Environment', StoredPath(ExpandFileName(Paths[Index]), True), True));
        TDataDirectory(AList[AList.Count - 1]).StoreDiscoveredPathsAbsolute := False;
      end;
  finally
    Paths.Free;
  end;
end;

function ScanWads(const ABaseDirectory: string; ASettings: TLauncherSettings; out ACacheChanged: Boolean): TObjectList;
var
  DirectoryIndex: Integer;
  EnvironmentDirectories: TObjectList;
  Seen: TStringList;
begin
  ACacheChanged := False;
  Result := TObjectList.Create(True);
  Seen := TStringList.Create;
  EnvironmentDirectories := TObjectList.Create(True);
  try
    Seen.CaseSensitive := False;
    Seen.Sorted := True;
    Seen.Duplicates := dupIgnore;
    for DirectoryIndex := 0 to ASettings.DataDirectories.Count - 1 do
      AddDirectoryWads(ABaseDirectory, ResolveStoredPath(ABaseDirectory, TDataDirectory(ASettings.DataDirectories[DirectoryIndex]).DirectoryName), TDataDirectory(ASettings.DataDirectories[DirectoryIndex]), ASettings.WadCache, Result, Seen, ACacheChanged);
    AddEnvironmentDirectories(EnvironmentDirectories);
    for DirectoryIndex := 0 to EnvironmentDirectories.Count - 1 do
      AddDirectoryWads(ABaseDirectory, ResolveStoredPath(ABaseDirectory, TDataDirectory(EnvironmentDirectories[DirectoryIndex]).DirectoryName), TDataDirectory(EnvironmentDirectories[DirectoryIndex]), ASettings.WadCache, Result, Seen, ACacheChanged);
  finally
    EnvironmentDirectories.Free;
    Seen.Free;
  end;
  if ASettings.WadCache.Count <> Result.Count then
    ACacheChanged := True;
  ASettings.WadCache.Clear;
  for DirectoryIndex := 0 to Result.Count - 1 do
    ASettings.WadCache.Add(CloneMetadata(TWadMetadata(Result[DirectoryIndex])));
end;

end.
