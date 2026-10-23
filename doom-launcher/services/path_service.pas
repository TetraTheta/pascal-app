unit path_service;

{$MODE objfpc}
{$H+}

interface

uses
  launcher_models;

function CanStoreRelative(const ABaseDirectory, APath: string): Boolean;
function CreateStoredPath(const ABaseDirectory, APath: string; AStoreAbsolute: Boolean): TStoredPath;
function ResolveStoredPath(const ABaseDirectory: string; const APath: TStoredPath): string;
function SanitizeDirectoryName(const AName: string): string;

implementation

uses
  Classes,
  SysUtils;

function NormalizedBase(const ABaseDirectory: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ABaseDirectory));
end;

function CanStoreRelative(const ABaseDirectory, APath: string): Boolean;
var
  BasePath: string;
  TargetPath: string;
begin
  BasePath := ExpandFileName(ABaseDirectory);
  TargetPath := ExpandFileName(APath);
  Result := (ExtractFileDrive(BasePath) = '') or SameText(ExtractFileDrive(BasePath), ExtractFileDrive(TargetPath));
end;

function CreateStoredPath(const ABaseDirectory, APath: string; AStoreAbsolute: Boolean): TStoredPath;
var
  AbsolutePath: string;
begin
  AbsolutePath := ExpandFileName(APath);
  if AStoreAbsolute then
    Exit(StoredPath(AbsolutePath, True));

  if not CanStoreRelative(ABaseDirectory, AbsolutePath) then
    raise EConvertError.Create('The selected path is on a different drive.');

  Result := StoredPath(ExtractRelativePath(NormalizedBase(ABaseDirectory), AbsolutePath), False);
end;

function ResolveStoredPath(const ABaseDirectory: string; const APath: TStoredPath): string;
begin
  if APath.Value = '' then
    Exit('');
  if APath.IsAbsolute then
    Exit(ExpandFileName(APath.Value));
  Result := ExpandFileName(NormalizedBase(ABaseDirectory) + APath.Value);
end;

function SanitizeDirectoryName(const AName: string): string;
const
  InvalidCharacters: set of Char = ['<', '>', ':', '"', '/', '\', '|', '?', '*'];
var
  CharacterIndex: Integer;
begin
  Result := Trim(AName);
  for CharacterIndex := 1 to Length(Result) do
    if (Result[CharacterIndex] in InvalidCharacters) or (Ord(Result[CharacterIndex]) < 32) then
      Result[CharacterIndex] := '-';
  while (Result <> '') and (Result[Length(Result)] in ['.', ' ']) do
    Delete(Result, Length(Result), 1);
  if Result = '' then
    Result := '_unsorted';
end;

end.
