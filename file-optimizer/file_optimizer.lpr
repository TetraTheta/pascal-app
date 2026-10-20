program FileOptimizer;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, SysUtils, Windows, main_form, options_form, uDarkStyleParams, uDarkStyleSchemes, uMetaDarkStyle;

{$R *.res}

var
  Index: Integer;
  HasPathArgument, HideWindow: Boolean;

begin
  if (ParamCount = 1) and (ParamStr(1) = '/?') then
  begin
    MessageBoxW(0, PWideChar(UnicodeString('FileOptimizer.exe <Path|File> [/Options]' + LineEnding + 'Use /Level=9, /PNGCopyMetadata=true, or another settings key to override an option.' + LineEnding + '/NOWINDOW runs without showing the main window.')), PWideChar(UnicodeString('FileOptimizer command-line help')), MB_OK or MB_ICONINFORMATION);
    Halt(0);
  end;
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  PreferredAppMode := pamForceDark;
  uMetaDarkStyle.ApplyMetaDarkStyle(DefaultDark);
  Application.Initialize;
  Application.Title:='FileOptimizer';
  HasPathArgument := False;
  HideWindow := False;
  for Index := 1 to ParamCount do
    if SameText(ParamStr(Index), '/NOWINDOW') then
      HideWindow := True
    else if (ParamStr(Index) <> '') and (ParamStr(Index)[1] <> '/') then
      HasPathArgument := True;
  if HideWindow and not HasPathArgument then
  begin
    MessageBoxW(0, 'A file or folder path is required with /NOWINDOW.', 'FileOptimizer', MB_OK or MB_ICONERROR);
    Halt(2);
  end;
  Application.ShowMainForm := not HideWindow;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
