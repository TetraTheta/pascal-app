program sourcemod_launcher;

{$MODE objfpc}
{$H+}

uses
  Interfaces,
  Forms,
  main,
  uDarkStyleParams,
  uDarkStyleSchemes,
  uDarkTheme;

{$R *.res}
{$R resource/images.rc}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.MainFormOnTaskbar := True;
  PreferredAppMode := pamForceDark;
  uDarkTheme.ApplyDarkTheme(DefaultDark);
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
