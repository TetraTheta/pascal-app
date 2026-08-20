unit main;

{$mode objfpc}{$H+}

interface

uses
  Buttons, Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Process, Registry, Windows;

type
  TMainForm = class(TForm)
    ButtonGModHammer: TBitBtn;
    ButtonGModHammerPP: TBitBtn;
    ButtonHL2Hammer: TBitBtn;
    ButtonHL2HammerPP: TBitBtn;
    ImageGMod: TImage;
    ImageHL2: TImage;
    StatusBar: TStatusBar;
    TextBoxTarget: TEdit;
    procedure ButtonGModHammerClick(Sender: TObject);
    procedure ButtonGModHammerMouseEnter(Sender: TObject);
    procedure ButtonGModHammerMouseLeave(Sender: TObject);
    procedure ButtonGModHammerPPClick(Sender: TObject);
    procedure ButtonGModHammerPPMouseEnter(Sender: TObject);
    procedure ButtonGModHammerPPMouseLeave(Sender: TObject);
    procedure ButtonHL2HammerClick(Sender: TObject);
    procedure ButtonHL2HammerMouseEnter(Sender: TObject);
    procedure ButtonHL2HammerMouseLeave(Sender: TObject);
    procedure ButtonHL2HammerPPClick(Sender: TObject);
    procedure ButtonHL2HammerPPMouseEnter(Sender: TObject);
    procedure ButtonHL2HammerPPMouseLeave(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LauncherKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FGModHammer: string;
    FGModHammerPP: string;
    FGModInstallPath: string;
    FHL2Hammer: string;
    FHL2HammerPP: string;
    FHL2InstallPath: string;
    FFilePath: string;
    procedure AssignKeyHandler(AControl: TControl);
    procedure ClearButtonStatus(Sender: TObject);
    procedure DisableGMod;
    procedure DisableHL2;
    function GetGModInstallPath: string;
    function GetHL2InstallPath: string;
    function GetRegistryPath(const APath: string): string;
    procedure LaunchHammer(const AExecutable: string);
    procedure LoadButtonImage(AButton: TBitBtn; const AResourceName: string);
    procedure LoadImage(AImage: TImage; const AResourceName: string);
    procedure LoadPngResource(ABitmap: Graphics.TBitmap; const AResourceName: string);
    function ResolveGModHammer: string;
    function ResolveGModHammerPP: string;
    function ResolveHL2Hammer: string;
    function ResolveHL2HammerPP: string;
    procedure SetButtonStatus(AButton: TBitBtn; const AText: string);
  public
    procedure InitializeTarget;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  LCLType;

const
  RegistryGModPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 4000';
  RegistryHL2Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 220';

procedure TMainForm.FormCreate(Sender: TObject);
begin
  LoadButtonImage(ButtonHL2Hammer, 'HAMMER_HL2');
  LoadButtonImage(ButtonHL2HammerPP, 'HAMMER_PLUSPLUS');
  LoadButtonImage(ButtonGModHammer, 'HAMMER_GMOD');
  LoadButtonImage(ButtonGModHammerPP, 'HAMMER_PLUSPLUS');
  LoadImage(ImageHL2, 'HL2');
  LoadImage(ImageGMod, 'GMOD');

  FHL2InstallPath := GetHL2InstallPath;
  FGModInstallPath := GetGModInstallPath;
  FHL2Hammer := ResolveHL2Hammer;
  FHL2HammerPP := ResolveHL2HammerPP;
  FGModHammer := ResolveGModHammer;
  FGModHammerPP := ResolveGModHammerPP;

  if FHL2InstallPath = '' then
    DisableHL2;
  if FHL2Hammer = '' then
    ButtonHL2Hammer.Enabled := False;
  if FHL2HammerPP = '' then
    ButtonHL2HammerPP.Enabled := False;

  if FGModInstallPath = '' then
    DisableGMod;
  if FGModHammer = '' then
    ButtonGModHammer.Enabled := False;
  if FGModHammerPP = '' then
    ButtonGModHammerPP.Enabled := False;

  AssignKeyHandler(Self);
  SelectFirst;
end;

procedure TMainForm.InitializeTarget;
begin
  if ParamCount < 1 then
    Exit;

  FFilePath := ExpandFileName(ParamStr(1));
  TextBoxTarget.Text := FFilePath;
  TextBoxTarget.SelStart := Length(TextBoxTarget.Text);
end;

procedure TMainForm.ButtonHL2HammerClick(Sender: TObject);
begin
  LaunchHammer(FHL2Hammer);
end;

procedure TMainForm.ButtonHL2HammerPPClick(Sender: TObject);
begin
  LaunchHammer(FHL2HammerPP);
end;

procedure TMainForm.ButtonGModHammerClick(Sender: TObject);
begin
  LaunchHammer(FGModHammer);
end;

procedure TMainForm.ButtonGModHammerPPClick(Sender: TObject);
begin
  LaunchHammer(FGModHammerPP);
end;

procedure TMainForm.ButtonHL2HammerMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonHL2Hammer, 'Half-Life 2 Hammer');
end;

procedure TMainForm.ButtonHL2HammerMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonHL2HammerPPMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonHL2HammerPP, 'Half-Life 2 Hammer++');
end;

procedure TMainForm.ButtonHL2HammerPPMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonGModHammerMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonGModHammer, 'Garry''s Mod Hammer');
end;

procedure TMainForm.ButtonGModHammerMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonGModHammerPPMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonGModHammerPP, 'Garry''s Mod Hammer++');
end;

procedure TMainForm.ButtonGModHammerPPMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.LauncherKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_1, VK_NUMPAD1:
      if ButtonHL2Hammer.Enabled then
        ButtonHL2Hammer.Click;
    VK_2, VK_NUMPAD2:
      if ButtonHL2HammerPP.Enabled then
        ButtonHL2HammerPP.Click;
    VK_3, VK_NUMPAD3:
      if ButtonGModHammer.Enabled then
        ButtonGModHammer.Click;
    VK_4, VK_NUMPAD4:
      if ButtonGModHammerPP.Enabled then
        ButtonGModHammerPP.Click;
  end;
end;

procedure TMainForm.AssignKeyHandler(AControl: TControl);
var
  ChildIndex: Integer;
begin
  if AControl is TWinControl then
  begin
    TWinControl(AControl).OnKeyDown := @LauncherKeyDown;
    for ChildIndex := 0 to TWinControl(AControl).ControlCount - 1 do
      AssignKeyHandler(TWinControl(AControl).Controls[ChildIndex]);
  end;
end;

procedure TMainForm.ClearButtonStatus(Sender: TObject);
begin
  StatusBar.SimpleText := '';
end;

procedure TMainForm.DisableHL2;
begin
  LoadImage(ImageHL2, 'HL2_GRAY');
  ButtonHL2Hammer.Enabled := False;
  ButtonHL2HammerPP.Enabled := False;
end;

procedure TMainForm.DisableGMod;
begin
  LoadImage(ImageGMod, 'GMOD_GRAY');
  ButtonGModHammer.Enabled := False;
  ButtonGModHammerPP.Enabled := False;
end;

function TMainForm.GetHL2InstallPath: string;
begin
  Result := GetRegistryPath(RegistryHL2Path);
end;

function TMainForm.GetGModInstallPath: string;
begin
  Result := GetRegistryPath(RegistryGModPath);
end;

function TMainForm.GetRegistryPath(const APath: string): string;
var
  Reg: TRegistry;
begin
  Result := '';
  Reg := TRegistry.Create(KEY_READ or KEY_WOW64_64KEY);
  try
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly(APath) and Reg.ValueExists('InstallLocation') then
        Result := Reg.ReadString('InstallLocation');
    except
      on E: Exception do
      begin
        MessageDlg(Format('Could not open ''%s'':%s%s', [APath, LineEnding, E.Message]), mtError, [mbOK], 0);
        Result := '';
      end;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TMainForm.LaunchHammer(const AExecutable: string);
var
  HammerProcess: TProcess;
begin
  if AExecutable = '' then
    Exit;

  HammerProcess := TProcess.Create(nil);
  try
    HammerProcess.Executable := AExecutable;
    if FFilePath <> '' then
      HammerProcess.Parameters.Add(FFilePath);
    HammerProcess.Execute;
  finally
    HammerProcess.Free;
  end;

  Application.Terminate;
end;

procedure TMainForm.LoadButtonImage(AButton: TBitBtn; const AResourceName: string);
var
  Bitmap: Graphics.TBitmap;
begin
  Bitmap := Graphics.TBitmap.Create;
  try
    LoadPngResource(Bitmap, AResourceName);
    AButton.Glyph.Assign(Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TMainForm.LoadImage(AImage: TImage; const AResourceName: string);
begin
  LoadPngResource(AImage.Picture.Bitmap, AResourceName);
end;

procedure TMainForm.LoadPngResource(ABitmap: Graphics.TBitmap; const AResourceName: string);
var
  Png: TPortableNetworkGraphic;
  Stream: TResourceStream;
begin
  Png := TPortableNetworkGraphic.Create;
  Stream := TResourceStream.Create(HInstance, AResourceName, RT_RCDATA);
  try
    Png.LoadFromStream(Stream);
    ABitmap.Assign(Png);
  finally
    Stream.Free;
    Png.Free;
  end;
end;

function TMainForm.ResolveHL2Hammer: string;
begin
  Result := IncludeTrailingPathDelimiter(FHL2InstallPath) + 'bin\hammer.exe';
  if not FileExists(Result) then
    Result := '';
end;

function TMainForm.ResolveHL2HammerPP: string;
begin
  Result := IncludeTrailingPathDelimiter(FHL2InstallPath) + 'bin\hammerplusplus.exe';
  if not FileExists(Result) then
    Result := '';
end;

function TMainForm.ResolveGModHammer: string;
begin
  Result := IncludeTrailingPathDelimiter(FGModInstallPath) + 'bin\hammer.exe';
  if not FileExists(Result) then
    Result := '';
end;

function TMainForm.ResolveGModHammerPP: string;
begin
  Result := IncludeTrailingPathDelimiter(FGModInstallPath) + 'bin\win64\hammerplusplus.exe';
  if not FileExists(Result) then
    Result := '';
end;

procedure TMainForm.SetButtonStatus(AButton: TBitBtn; const AText: string);
begin
  AButton.Hint := AText;
  StatusBar.SimpleText := AText;
end;

end.
