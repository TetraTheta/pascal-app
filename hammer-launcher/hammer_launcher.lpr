program hammer_launcher;

{$MODE objfpc}
{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
{$IFDEF HASAMIGA}
  athreads,
{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  main,
  { you can add units after this }
  uDarkStyleParams,
  uDarkStyleSchemes,
  uDarkTheme;

{$R *.res}
{$R resource\images.rc}

begin
  RequireDerivedFormResource := True;
  {$PUSH}
  {$WARN 5044 OFF}
  Application.Scaled := True;
  Application.MainFormOnTaskbar := True;
  {$POP}

  PreferredAppMode := pamForceDark;
  uDarkTheme.ApplyDarkTheme(DefaultDark);

  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  MainForm.InitializeTarget;
  Application.Run;
end.
