unit optimizer_configuration;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TOptionKind = (okBoolean, okInteger, okText);

  TOptionSpec = record
    Section: string;
    Name: string;
    Kind: TOptionKind;
    DefaultValue: string;
  end;

  { TOptimizerConfiguration loads settings from AppData or the executable directory and saves to AppData. }
  TOptimizerConfiguration = class
  private
    FPath: string;
    FLoadPath: string;
    FValues: TStringList;
    function SettingName(const ASection, AName: string): string;
  public
    constructor Create(const AExecutablePath: string);
    destructor Destroy; override;
    function GetBoolean(const ASection, AName: string): Boolean;
    function GetInteger(const ASection, AName: string): Integer;
    function GetText(const ASection, AName: string): string;
    procedure Load;
    procedure Save;
    procedure SetBoolean(const ASection, AName: string; const AValue: Boolean);
    procedure SetInteger(const ASection, AName: string; const AValue: Integer);
    procedure SetText(const ASection, AName, AValue: string);
    property Path: string read FPath;
  end;

function OptionCount: Integer;
function OptionSpec(const AIndex: Integer): TOptionSpec;

implementation

uses
  IniFiles;

const
  OptionDefinitions: array[0..48] of string = (
    'General|Language|T|auto',
    'General|Level|I|5',
    'General|ParallelEnabled|B|false',
    'General|ParallelCount|I|2',
    'General|AllowDuplicates|B|false',
    'General|AllowMultipleInstances|B|false',
    'General|AlwaysOnTop|B|false',
    'General|BeepWhenDone|B|false',
    'General|ClearWhenComplete|B|false',
    'General|Debug|B|false',
    'General|DisablePluginMask|T|',
    'General|DisableSleep|B|true',
    'General|DoNotCreateBackups|B|true',
    'General|DoNotUseRecycleBin|B|false',
    'General|EnableCache|B|false',
    'General|ExcludeMask|T|',
    'General|FilenameFormat|I|0',
    'General|IncludeMask|T|',
    'General|KeepAttributes|B|false',
    'General|LeanifyIterations|I|-1',
    'General|LogLevel|I|0',
    'General|PersistentGrid|B|false',
    'General|PNGWolfIterations|I|-1',
    'General|ProcessPriority|I|32',
    'General|ShutdownWhenDone|B|false',
    'General|StartupDelay|I|3000',
    'General|TempDirectory|T|',
    'BMP|CopyMetadata|B|false',
    'CSS|EnableTidy|B|false',
    'CSS|Template|T|low',
    'EXE|DisablePETrim|B|false',
    'EXE|EnableUPX|B|false',
    'GIF|AllowLossy|B|false',
    'GIF|CopyMetadata|B|false',
    'GZ|CopyMetadata|B|false',
    'HTML|EnableTidy|B|false',
    'JPEG|AllowLossy|B|false',
    'JPEG|CopyMetadata|B|false',
    'JPEG|UseArithmeticEncoding|B|false',
    'JS|AdditionalExtensions|T|',
    'JS|EnableJSMin|B|false',
    'LUA|EnableLeanify|B|false',
    'Misc|CopyMetadata|B|false',
    'Misc|Disable|B|false',
    'MP3|CopyMetadata|B|false',
    'MP4|CopyMetadata|B|false',
    'PCX|CopyMetadata|B|false',
    'PDF|CustomDPI|I|150',
    'PDF|Profile|T|none'
  );

  MoreOptionDefinitions: array[0..15] of string = (
    'PDF|SkipLayered|B|false',
    'PNG|AllowLossy|B|false',
    'PNG|CopyMetadata|B|false',
    'TGA|CopyMetadata|B|false',
    'TIFF|CopyMetadata|B|false',
    'WAV|CopyMetadata|B|false',
    'WAV|StripSilence|B|false',
    'WEBP|AllowLossy|B|false',
    'XML|EnableLeanify|B|false',
    'ZIP|CopyMetadata|B|false',
    'ZIP|Recurse|B|false',
    'Window|Left|I|-1',
    'Window|Top|I|-1',
    'Window|Width|I|900',
    'Window|Height|I|600',
    'Window|Maximized|B|false'
  );

function OptionCount: Integer;
begin
  Result := Length(OptionDefinitions) + Length(MoreOptionDefinitions);
end;

function StripIniComment(const AValue: string): string;
var
  Index: Integer;
  Quote: Char;
begin
  Quote := #0;
  for Index := 1 to Length(AValue) do
  begin
    if (AValue[Index] in ['''', '"']) then
    begin
      if Quote = #0 then
        Quote := AValue[Index]
      else if Quote = AValue[Index] then
        Quote := #0;
    end
    else if (Quote = #0) and (AValue[Index] in [';', '#']) and ((Index = 1) or (AValue[Index - 1] in [' ', #9])) then
      Exit(Trim(Copy(AValue, 1, Index - 1)));
  end;
  Result := Trim(AValue);
end;

function OptionSpec(const AIndex: Integer): TOptionSpec;
var
  Definition: string;
  First, Second, Third: SizeInt;
begin
  if AIndex < Length(OptionDefinitions) then
    Definition := OptionDefinitions[AIndex]
  else
    Definition := MoreOptionDefinitions[AIndex - Length(OptionDefinitions)];
  First := Pos('|', Definition);
  Second := Pos('|', Definition, First + 1);
  Third := Pos('|', Definition, Second + 1);
  Result.Section := Copy(Definition, 1, First - 1);
  Result.Name := Copy(Definition, First + 1, Second - First - 1);
  case Definition[Second + 1] of
    'B': Result.Kind := okBoolean;
    'I': Result.Kind := okInteger;
  else
    Result.Kind := okText;
  end;
  Result.DefaultValue := Copy(Definition, Third + 1, MaxInt);
end;

constructor TOptimizerConfiguration.Create(const AExecutablePath: string);
var
  AppDataPath, ProgramPath: string;
begin
  inherited Create;
  ProgramPath := ChangeFileExt(AExecutablePath, '.ini');
  AppDataPath := GetEnvironmentVariable('APPDATA');
  if AppDataPath = '' then
    AppDataPath := GetAppConfigDir(False);
  FPath := IncludeTrailingPathDelimiter(AppDataPath) + 'FileOptimizer' + PathDelim + 'FileOptimizer.ini';
  if FileExists(FPath) then
    FLoadPath := FPath
  else if FileExists(ProgramPath) then
    FLoadPath := ProgramPath
  else
    FLoadPath := FPath;
  FValues := TStringList.Create;
  FValues.NameValueSeparator := '=';
  Load;
  if not FileExists(FLoadPath) then
    Save;
end;

destructor TOptimizerConfiguration.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

function TOptimizerConfiguration.SettingName(const ASection, AName: string): string;
begin
  Result := ASection + '.' + AName;
end;

function TOptimizerConfiguration.GetBoolean(const ASection, AName: string): Boolean;
begin
  Result := SameText(GetText(ASection, AName), 'true');
end;

function TOptimizerConfiguration.GetInteger(const ASection, AName: string): Integer;
begin
  Result := StrToIntDef(GetText(ASection, AName), 0);
end;

function TOptimizerConfiguration.GetText(const ASection, AName: string): string;
begin
  Result := FValues.Values[SettingName(ASection, AName)];
end;

procedure TOptimizerConfiguration.Load;
var
  ConfigFile: TMemIniFile;
  Index: Integer;
  Spec: TOptionSpec;
begin
  ConfigFile := TMemIniFile.Create(FLoadPath);
  try
    FValues.Clear;
    for Index := 0 to OptionCount - 1 do
    begin
      Spec := OptionSpec(Index);
      FValues.Values[SettingName(Spec.Section, Spec.Name)] := StripIniComment(ConfigFile.ReadString(Spec.Section, Spec.Name, Spec.DefaultValue));
    end;
  finally
    ConfigFile.Free;
  end;
end;

procedure TOptimizerConfiguration.Save;
var
  ConfigFile: TMemIniFile;
  Index: Integer;
  Spec: TOptionSpec;
begin
  if not ForceDirectories(ExtractFileDir(FPath)) then
    raise EFCreateError.CreateFmt('Cannot create settings directory: %s', [ExtractFileDir(FPath)]);
  ConfigFile := TMemIniFile.Create(FPath);
  try
    for Index := 0 to OptionCount - 1 do
    begin
      Spec := OptionSpec(Index);
      ConfigFile.WriteString(Spec.Section, Spec.Name, GetText(Spec.Section, Spec.Name));
    end;
    ConfigFile.UpdateFile;
  finally
    ConfigFile.Free;
  end;
end;

procedure TOptimizerConfiguration.SetBoolean(const ASection, AName: string;
  const AValue: Boolean);
begin
  if AValue then
    SetText(ASection, AName, 'true')
  else
    SetText(ASection, AName, 'false');
end;

procedure TOptimizerConfiguration.SetInteger(const ASection, AName: string;
  const AValue: Integer);
begin
  SetText(ASection, AName, IntToStr(AValue));
end;

procedure TOptimizerConfiguration.SetText(const ASection, AName, AValue: string);
begin
  FValues.Values[SettingName(ASection, AName)] := AValue;
end;

end.
