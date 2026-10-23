unit DarkThemeLazarusOptions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  LazConfigStorage, LazFileUtils, LazFileCache,
  LazLoggerBase, ComCtrls, Graphics,
  BaseIDEIntf;

const
  amOptAllowDarkName='Allow dark';
  amOptForceDarkName='Force dark';
  amOptForceLightName='Force light';
resourcestring
  RSamOptAllowDarkName=amOptAllowDarkName;
  RSamOptForceDarkName=amOptForceDarkName;
  RSamOptForceLightName=amOptForceLightName;

type
  TAppModeOpt=(amOptAllowDark,amOptForceDark,amOptForceLight);

const
  AppModeOptStr:array[TAppModeOpt] of String=(amOptAllowDarkName,amOptForceDarkName,amOptForceLightName);
  AppModeOptLocalizedStr:array[TAppModeOpt] of String=(RSamOptAllowDarkName,RSamOptForceDarkName,RSamOptForceLightName);

type

  TDarkThemeLazarusOptions=class
  private
    const
      DefaultAppMode:TAppModeOpt=amOptAllowDark;
      DefaultColorScheme:String='Dark';
    var
      FAppMode:TAppModeOpt;
      FColorScheme:String;
      FChangeStamp:Integer;
      FLastSavedChangeStamp:Integer;
    procedure SetAppMode(AValue:TAppModeOpt);
    procedure SetColorScheme(AValue:String);
    function GetModified:Boolean;
    procedure SetModified(AValue: Boolean);
    function Str2AppModeOpt(str:string):TAppModeOpt;
  public
    constructor Create;
    procedure SaveSafe;
    procedure LoadSafe;
    procedure SaveToFile(AFilename:String);
    procedure LoadFromFile(AFilename:String);
    procedure IncreaseChangeStamp;
  public
    property ChangeStamp:Integer read FChangeStamp;
    property Modified:Boolean read GetModified write SetModified;

    property AppMode:TAppModeOpt read FAppMode write SetAppMode;
    property ColorScheme:String  read FColorScheme write SetColorScheme;
  end;

const
  DarkThemeLazarusFileName='darkthemelazarusoptions.xml';

var
  DarkThemeLazarusOpt: TDarkThemeLazarusOptions = nil;

implementation

{ TDockedOptions }

function TDarkThemeLazarusOptions.GetModified:Boolean;
begin
  Result:=FLastSavedChangeStamp<>FChangeStamp;
end;

procedure TDarkThemeLazarusOptions.SetModified(AValue:Boolean);
begin
  if AValue then
    IncreaseChangeStamp
  else
    FLastSavedChangeStamp:=FChangeStamp;
end;

procedure TDarkThemeLazarusOptions.SetAppMode(AValue:TAppModeOpt);
begin
  if FAppMode=AValue then Exit;
  FAppMode:=AValue;
  IncreaseChangeStamp;
end;

procedure TDarkThemeLazarusOptions.SetColorScheme(AValue:String);
begin
  if FColorScheme=AValue then Exit;
  FColorScheme:=AValue;
  IncreaseChangeStamp;
end;

constructor TDarkThemeLazarusOptions.Create;
begin
  FAppMode:=DefaultAppMode;
  FChangeStamp:=LUInvalidChangeStamp+1;
  FLastSavedChangeStamp:=FChangeStamp;
end;

procedure TDarkThemeLazarusOptions.SaveSafe;
begin
  try
    SaveToFile(DarkThemeLazarusFileName);
    Modified:=False;
  except
    on E: Exception do
      DebugLn(['Error: (lazarus) [TDarkThemeLazarusOptions.SaveSafe] ', E.Message]);
  end;
end;

procedure TDarkThemeLazarusOptions.LoadSafe;
begin
  try
    LoadFromFile(DarkThemeLazarusFileName);
  except
    on E: Exception do
      DebugLn(['Error: (lazarus) [TDarkThemeLazarusOptions.LoadSafe] ', E.Message]);
  end;
  Modified:=False;
end;

procedure TDarkThemeLazarusOptions.SaveToFile(AFilename: String);
var
  Cfg: TConfigStorage;
begin
  Cfg:=GetIDEConfigStorage(AFilename,False);
  try
    Cfg.SetDeleteValue('AppMode/Value',AppModeOptStr[AppMode],AppModeOptStr[DefaultAppMode]);
    Cfg.SetDeleteValue('ColorScheme/Value',ColorScheme,DefaultColorScheme);
  finally
    Cfg.Free;
  end;
end;

function TDarkThemeLazarusOptions.Str2AppModeOpt(str:string):TAppModeOpt;
var
  i:TAppModeOpt;
begin
  for i:=low(AppModeOptStr) to high(AppModeOptStr) do
    if AppModeOptStr[i]=str then
      exit(i);
  result:=DefaultAppMode;
end;

procedure TDarkThemeLazarusOptions.LoadFromFile(AFilename: String);
var
  Cfg: TConfigStorage;
begin
  Cfg := GetIDEConfigStorage(AFilename,True);
  try
    AppMode:= Str2AppModeOpt(Cfg.GetValue('AppMode/Value',AppModeOptStr[DefaultAppMode]));
    ColorScheme:= Cfg.GetValue('ColorScheme/Value',DefaultColorScheme);
  finally
    Cfg.Free;
  end;
end;

procedure TDarkThemeLazarusOptions.IncreaseChangeStamp;
begin
  LUIncreaseChangeStamp(FChangeStamp);
end;

end.

