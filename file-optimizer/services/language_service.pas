unit language_service;

{$MODE objfpc}
{$H+}

interface

uses
  IniFiles;

type
  { TLanguageService uses built-in English text when a translation is absent. }
  TLanguageService = class
  private
    FFile: TMemIniFile;
  public
    constructor Create(const AExecutablePath, ALanguage: string);
    destructor Destroy; override;
    function Text(const AKey, AEnglish: string): string;
  end;

implementation

uses
  SysUtils,
  Windows;

constructor TLanguageService.Create(const AExecutablePath, ALanguage: string);
var
  Language: string;
  LanguagePath: string;
begin
  inherited Create;
  Language := ALanguage;
  if SameText(Language, 'auto') then begin
    if (GetUserDefaultLangID and $3FF) = LANG_KOREAN then
      Language := 'ko'
    else
      Language := 'en';
  end;
  if SameText(Language, 'ko') then begin
    LanguagePath := IncludeTrailingPathDelimiter(ExtractFilePath(AExecutablePath)) + 'lang' + PathDelim + 'ko.ini';
    if FileExists(LanguagePath) then
      FFile := TMemIniFile.Create(LanguagePath);
  end;
end;

destructor TLanguageService.Destroy;
begin
  FFile.Free;
  inherited Destroy;
end;

function TLanguageService.Text(const AKey, AEnglish: string): string;
begin
  Result := AEnglish;
  if Assigned(FFile) then begin
    Result := FFile.ReadString('Strings', AKey, AEnglish);
    if Result = '' then
      Result := AEnglish;
  end;
end;

end.
