program gmod_description_generator;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, main,
  { you can add units after this }
  uDarkStyleParams, uDarkStyleSchemes, uMetaDarkStyle;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}

  PreferredAppMode := pamForceDark;
  uMetaDarkStyle.ApplyMetaDarkStyle(DefaultDark);

  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

