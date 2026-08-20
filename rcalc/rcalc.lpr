program rcalc;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  SysUtils,
  Forms, main,
  { you can add units after this }
  uDarkStyleParams, uDarkStyleSchemes, uMetaDarkStyle;

{$R *.res}

var
  A: Double;
  X: Double;
  Y: Double;

begin
  if (ParamCount < 1) or not TryStrToFloat(ParamStr(1), X) then X := 0;
  if (ParamCount < 2) or not TryStrToFloat(ParamStr(2), Y) then Y := 0;
  if (ParamCount < 3) or not TryStrToFloat(ParamStr(3), A) then A := 0;

  RequireDerivedFormResource:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}

  PreferredAppMode := pamForceDark;
  uMetaDarkStyle.ApplyMetaDarkStyle(DefaultDark);

  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  MainForm.InitializeValues(X, Y, A);
  Application.Run;
end.
