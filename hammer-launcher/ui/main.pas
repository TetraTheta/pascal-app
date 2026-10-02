unit main;
{$warn 5024 off}

{$mode objfpc}{$H+}

interface

uses
  Buttons, Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  ComCtrls, Process;

type

  { TMainForm }

  TMainForm = class(TForm)
    ButtonHL2Hammer: TBitBtn;
    ButtonHL2HammerPP: TBitBtn;
    ButtonGModHammer: TBitBtn;
    ButtonGModHammerPP: TBitBtn;
    ButtonEZ2Hammer: TBitBtn;
    ButtonEZ2HammerPP: TBitBtn;
    ImageHL2: TImage;
    ImageGMod: TImage;
    ImageEZ2: TImage;
    StatusBar: TStatusBar;
    TextBoxTarget: TEdit;
    procedure ButtonHL2HammerClick(Sender: TObject);
    procedure ButtonHL2HammerMouseEnter(Sender: TObject);
    procedure ButtonHL2HammerMouseLeave(Sender: TObject);
    procedure ButtonHL2HammerPPClick(Sender: TObject);
    procedure ButtonHL2HammerPPMouseEnter(Sender: TObject);
    procedure ButtonHL2HammerPPMouseLeave(Sender: TObject);
    procedure ButtonGModHammerClick(Sender: TObject);
    procedure ButtonGModHammerMouseEnter(Sender: TObject);
    procedure ButtonGModHammerMouseLeave(Sender: TObject);
    procedure ButtonGModHammerPPClick(Sender: TObject);
    procedure ButtonGModHammerPPMouseEnter(Sender: TObject);
    procedure ButtonGModHammerPPMouseLeave(Sender: TObject);
    procedure ButtonEZ2HammerClick(Sender: TObject);
    procedure ButtonEZ2HammerMouseEnter(Sender: TObject);
    procedure ButtonEZ2HammerMouseLeave(Sender: TObject);
    procedure ButtonEZ2HammerPPClick(Sender: TObject);
    procedure ButtonEZ2HammerPPMouseEnter(Sender: TObject);
    procedure ButtonEZ2HammerPPMouseLeave(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LauncherKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FHL2Hammer: string;
    FHL2HammerPP: string;
    FGModHammer: string;
    FGModHammerPP: string;
    FEZ2Hammer: string;
    FEZ2HammerPP: string;
    FFilePath: string;
    procedure AssignKeyHandler(AControl: TControl);
    procedure ClearButtonStatus(Sender: TObject);
    procedure LaunchHammer(const AExecutable: string);
    procedure LoadButtonImage(AButton: TBitBtn; const AResourceName: string);
    procedure LoadImage(AImage: TImage; const AResourceName: string);
    procedure LoadPngResource(ABitmap: Graphics.TBitmap; const AResourceName: string);
    procedure SetButtonStatus(AButton: TBitBtn; const AText: string);
  public
    procedure InitializeTarget;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  launcher_configuration, LCLType;

procedure TMainForm.FormCreate(Sender: TObject);
var
  Configuration: TLauncherConfiguration;
begin
  LoadButtonImage(ButtonHL2Hammer, 'HAMMER_HL2');
  LoadButtonImage(ButtonHL2HammerPP, 'HAMMER_PLUSPLUS');
  LoadButtonImage(ButtonGModHammer, 'HAMMER_GMOD');
  LoadButtonImage(ButtonGModHammerPP, 'HAMMER_PLUSPLUS');
  LoadButtonImage(ButtonEZ2Hammer, 'HAMMER_HL2');
  LoadButtonImage(ButtonEZ2HammerPP, 'HAMMER_PLUSPLUS');
  LoadImage(ImageHL2, 'HL2');
  LoadImage(ImageGMod, 'GMOD');
  LoadImage(ImageEZ2, 'EZ2');

  Configuration := LoadLauncherConfiguration(Application.ExeName);
  FHL2Hammer := Configuration.HL2Hammer;
  FHL2HammerPP := Configuration.HL2HammerPP;
  FGModHammer := Configuration.GModHammer;
  FGModHammerPP := Configuration.GModHammerPP;
  FEZ2Hammer := Configuration.EZ2Hammer;
  FEZ2HammerPP := Configuration.EZ2HammerPP;

  ButtonHL2Hammer.Enabled := FileExists(FHL2Hammer);
  ButtonHL2HammerPP.Enabled := FileExists(FHL2HammerPP);
  ButtonGModHammer.Enabled := FileExists(FGModHammer);
  ButtonGModHammerPP.Enabled := FileExists(FGModHammerPP);
  ButtonEZ2Hammer.Enabled := FileExists(FEZ2Hammer);
  ButtonEZ2HammerPP.Enabled := FileExists(FEZ2HammerPP);

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

procedure TMainForm.ButtonEZ2HammerClick(Sender: TObject);
begin
  LaunchHammer(FEZ2Hammer);
end;

procedure TMainForm.ButtonEZ2HammerPPClick(Sender: TObject);
begin
  LaunchHammer(FEZ2HammerPP);
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

procedure TMainForm.ButtonEZ2HammerMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonEZ2Hammer, 'Entropy: Zero 2 Hammer');
end;

procedure TMainForm.ButtonEZ2HammerMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonEZ2HammerPPMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonEZ2HammerPP, 'Entropy: Zero 2 Hammer++');
end;

procedure TMainForm.ButtonEZ2HammerPPMouseLeave(Sender: TObject);
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
    VK_5, VK_NUMPAD5:
      if ButtonEZ2Hammer.Enabled then
        ButtonEZ2Hammer.Click;
    VK_6, VK_NUMPAD6:
      if ButtonEZ2HammerPP.Enabled then
        ButtonEZ2HammerPP.Click;
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

procedure TMainForm.LaunchHammer(const AExecutable: string);
var
  HammerProcess: TProcess;
begin
  if not FileExists(AExecutable) then
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

procedure TMainForm.SetButtonStatus(AButton: TBitBtn; const AText: string);
begin
  AButton.Hint := AText;
  StatusBar.SimpleText := AText;
end;

end.
