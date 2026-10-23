unit registerDarkThemeLazarus;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  IDEOptionsIntf, IDEOptEditorIntf, LazIDEIntf, lazconf,
  uDarkStyleParams, uDarkStyleSchemes, uDarkTheme,
  DarkThemeLazarusOptionsFrame, DarkThemeLazarusOptions;

var
  DarkThemeOptionsID: integer = 1000;


procedure Register;

implementation

function AppModeOpt2PreferredAppMode(am:TAppModeOpt):TPreferredAppMode;
begin
  case am of
    amOptAllowDark:result:=pamAllowDark;
    amOptForceDark:result:=pamForceDark;
   amOptForceLight:result:=pamForceLight;
  end;
end;

procedure SetDarkStyle;
begin
 {$IF DEFINED(MSWINDOWS)}
  LoadLResources;
  LoadPath(GetPrimaryConfigPath+'/userschemes','*.'+DSColorsTypeName);
  LoadPath(GetSecondaryConfigPath+'/userschemes','*.'+DSColorsTypeName);
  DarkThemeLazarusOpt:=TDarkThemeLazarusOptions.Create;
  DarkThemeLazarusOpt.LoadSafe;
  PreferredAppMode:=AppModeOpt2PreferredAppMode(DarkThemeLazarusOpt.AppMode);
  ApplyDarkTheme(GetScheme(DarkThemeLazarusOpt.ColorScheme));
 {$ENDIF}
end;

procedure Register;
begin
  DarkThemeOptionsID:=RegisterIDEOptionsEditor(GroupEnvironment,
                                                   TDarkStyleDSGNOptionsFrame,
                                                   DarkThemeOptionsID)^.Index;
end;

initialization
  AddBootHandler(libhEnvironmentOptionsLoaded,@SetDarkStyle);
end.

