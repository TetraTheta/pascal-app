unit main;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  StdCtrls,
  ExtCtrls,
  ComCtrls,
  Menus,
  Graphics,
  Contnrs,
  runtime_resource,
  launcher_configuration;

type
  TMainForm = class(TForm)
    ModList: TListBox;
    ActionPanel: TPanel;
    PlayButton: TRuntimeResourceBitBtn;
    RefreshButton: TButton;
    StatusBar: TStatusBar;
    MainMenu: TMainMenu;
    FileMenu: TMenuItem;
    ExitMenu: TMenuItem;
    SettingsMenu: TMenuItem;
    ExitOnLaunchMenu: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure RefreshClick(Sender: TObject);
    procedure PlayClick(Sender: TObject);
    procedure ExitOnLaunchClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure SelectionChange(Sender: TObject; User: Boolean);
    procedure DrawMod(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure ModMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ModMouseLeave(Sender: TObject);
  private
    FMods: TObjectList;
    FIcons: TObjectList;
    FFallback: TPortableNetworkGraphic;
    FSettings: TLauncherSettings;
    FIniFile: string;
    FSdkDirectory: string;
    FHintIndex: Integer;
    procedure UpdatePlayButton;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  Types,
  Dialogs,
  Process,
  Windows,
  mod_service,
  icon_service,
  LCLType;

procedure TMainForm.ExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  Args: array of string;
  I: Integer;
  Resource: TResourceStream;
begin
  FHintIndex := -1;
  FMods := TObjectList.Create(True);
  FIcons := TObjectList.Create(True);
  FFallback := TPortableNetworkGraphic.Create;
  Resource := TResourceStream.Create(HInstance, 'HL2', RT_RCDATA);
  try
    FFallback.LoadFromStream(Resource);
  finally
    Resource.Free;
  end;
  FSettings.ExitOnLaunch := True;
  SetLength(Args, ParamCount);
  for I := 1 to ParamCount do
    Args[I - 1] := ParamStr(I);
  try
    FIniFile := FindLauncherConfiguration(Application.ExeName, Args);
    FSettings := LoadSettings(FIniFile);
    if not FileExists(FIniFile) then
      SaveSettings(FIniFile, FSettings);
  except
    on E: Exception do begin
      MessageDlg('Settings error', E.Message, mtError, [mbOK], 0);
      // Do not overwrite a configuration that could not be read.
      FIniFile := '';
    end;
  end;
  ExitOnLaunchMenu.Checked := FSettings.ExitOnLaunch;
  RefreshClick(nil);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FIcons.Free;
  FMods.Free;
  FFallback.Free;
end;

procedure TMainForm.UpdatePlayButton;
begin
  PlayButton.Enabled := (ModList.ItemIndex >= 0) and (FSdkDirectory <> '');
end;

procedure TMainForm.RefreshClick(Sender: TObject);
var
  Selected: string;
  I, Failures: Integer;
  ModIcon: TPortableNetworkGraphic;
begin
  Selected := FSettings.LastLaunch;
  if ModList.ItemIndex >= 0 then
    Selected := TSourceMod(FMods[ModList.ItemIndex]).Directory;
  ModMouseLeave(nil);
  ModList.Clear;
  UpdatePlayButton;
  ModList.Repaint;
  StatusBar.SimpleText := 'Refreshing source mods...';
  StatusBar.Repaint;
  ModList.Items.BeginUpdate;
  try
    FIcons.Clear;
    try
      DiscoverMods(FindSteamDirectory, FMods, FSdkDirectory, Failures);
    except
      on E: Exception do begin
        FSdkDirectory := '';
        FMods.Clear;
        StatusBar.SimpleText := 'Discovery failed: ' + E.Message;
        Exit;
      end;
    end;
    for I := 0 to FMods.Count - 1 do begin
      ModList.Items.Add(TSourceMod(FMods[I]).Title);
      ModIcon := TPortableNetworkGraphic.Create;
      FIcons.Add(ModIcon);
      LoadModIcon(TSourceMod(FMods[I]).IconFile, FFallback, ModIcon);
    end;
    if ModList.Count > 0 then
      ModList.ItemIndex := 0;
    for I := 0 to FMods.Count - 1 do
      if SameText(TSourceMod(FMods[I]).Directory, Selected) then begin
        ModList.ItemIndex := I;
        Break;
      end;
    StatusBar.SimpleText := Format('%d source mods; %d files could not be read.', [FMods.Count, Failures]);
    if FSdkDirectory = '' then
      StatusBar.SimpleText := StatusBar.SimpleText + ' SDK 2013 Singleplayer not found.';
  finally
    ModList.Items.EndUpdate;
    UpdatePlayButton;
  end;
end;

procedure TMainForm.PlayClick(Sender: TObject);
var
  GameProcess: TProcess;
begin
  if not PlayButton.Enabled then
    Exit;
  GameProcess := TProcess.Create(nil);
  try
    try
      ConfigureLaunch(GameProcess, FSdkDirectory, TSourceMod(FMods[ModList.ItemIndex]).Directory);
      GameProcess.Execute;
    except
      on E: Exception do begin
        MessageDlg('Launch error', E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    GameProcess.Free;
  end;
  FSettings.LastLaunch := TSourceMod(FMods[ModList.ItemIndex]).Directory;
  try
    if FIniFile = '' then
      raise EInOutError.Create('Settings are unavailable. Restart with a valid -ini path.');
    SaveSettings(FIniFile, FSettings);
  except
    on E: Exception do begin
      MessageDlg('Settings error', 'The game process started, but settings could not be saved.' + LineEnding + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  if FSettings.ExitOnLaunch then
    Close;
end;

procedure TMainForm.ExitOnLaunchClick(Sender: TObject);
var
  Settings: TLauncherSettings;
begin
  Settings := FSettings;
  Settings.ExitOnLaunch := not Settings.ExitOnLaunch;
  try
    if FIniFile = '' then
      raise EInOutError.Create('Settings are unavailable. Restart with a valid -ini path.');
    SaveSettings(FIniFile, Settings);
    FSettings := Settings;
  except
    on E: Exception do
      MessageDlg('Settings error', E.Message, mtError, [mbOK], 0);
  end;
  ExitOnLaunchMenu.Checked := FSettings.ExitOnLaunch;
end;

procedure TMainForm.SelectionChange(Sender: TObject; User: Boolean);
begin
  UpdatePlayButton;
end;

procedure TMainForm.DrawMod(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  IconRect: TRect;
  Size, Padding: Integer;
begin
  ModList.Canvas.FillRect(ARect);
  Size := Scale96ToForm(16);
  Padding := Scale96ToForm(6);
  IconRect :=
      Types.Rect(ARect.Left + Padding, ARect.Top + (ARect.Height - Size) div 2, ARect.Left + Padding + Size, ARect.Top + (ARect.Height + Size) div 2);
  if (Index >= 0) and (Index < FIcons.Count) then
    ModList.Canvas.StretchDraw(IconRect, TPortableNetworkGraphic(FIcons[Index]));
  ModList.Canvas.TextRect(ARect, IconRect.Right + Padding, ARect.Top + (ARect.Height - ModList.Canvas.TextHeight('Ag')) div 2, ModList.Items[Index]);
end;

procedure TMainForm.ModMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Index: Integer;
begin
  Index := ModList.ItemAtPos(Types.Point(X, Y), True);
  if Index = FHintIndex then
    Exit;
  Application.CancelHint;
  FHintIndex := Index;
  ModList.Hint := '';
  if (Index >= 0) and (Index < FMods.Count) then begin
    ModList.Hint := TSourceMod(FMods[Index]).Directory;
    Application.ActivateHint(ModList.ClientToScreen(Types.Point(X, Y)));
  end;
end;

procedure TMainForm.ModMouseLeave(Sender: TObject);
begin
  Application.CancelHint;
  FHintIndex := -1;
  ModList.Hint := '';
end;

end.
