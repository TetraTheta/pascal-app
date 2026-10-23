program doom_launcher;

{$MODE objfpc}
{$H+}

uses
  Interfaces,
  Forms,
  main,
  data_directories_dialog,
  launch_options_dialog,
  launch_arguments_dialog,
  path_item_dialog,
  launcher_configuration,
  launcher_models,
  launch_service,
  path_service,
  profile_service,
  wad_service,
  uDarkStyleParams,
  uDarkStyleSchemes,
  uDarkTheme;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'Doom Launcher';
  Application.Scaled := True;
  // Application.MainFormOnTaskbar := True;
  PreferredAppMode := pamForceDark;
  uDarkTheme.ApplyDarkTheme(DefaultDark);
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
