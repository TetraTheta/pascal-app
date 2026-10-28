unit main;
{$WARN 5024 off}

{$MODE objfpc}
{$H+}

interface

uses
  Buttons,
  Classes,
  SysUtils,
  Forms,
  Controls,
  StdCtrls,
  ComCtrls,
  Process,
  runtime_resource;

type

  { TMainForm }

  TMainForm = class(TForm)
    ButtonHL2HammerStock: TRuntimeResourceBitBtn;
    ButtonHL2HammerCustom: TRuntimeResourceBitBtn;
    ButtonGModHammerStock: TRuntimeResourceBitBtn;
    ButtonGModHammerCustom: TRuntimeResourceBitBtn;
    ButtonEZ2HammerStock: TRuntimeResourceBitBtn;
    ButtonEZ2HammerCustom: TRuntimeResourceBitBtn;
    ImageHL2: TRuntimeResourceImage;
    ImageGMod: TRuntimeResourceImage;
    ImageEZ2: TRuntimeResourceImage;
    StatusBar: TStatusBar;
    TextBoxTarget: TEdit;
    procedure ButtonHL2HammerStockClick(Sender: TObject);
    procedure ButtonHL2HammerStockMouseEnter(Sender: TObject);
    procedure ButtonHL2HammerStockMouseLeave(Sender: TObject);
    procedure ButtonHL2HammerCustomClick(Sender: TObject);
    procedure ButtonHL2HammerCustomMouseEnter(Sender: TObject);
    procedure ButtonHL2HammerCustomMouseLeave(Sender: TObject);
    procedure ButtonGModHammerStockClick(Sender: TObject);
    procedure ButtonGModHammerStockMouseEnter(Sender: TObject);
    procedure ButtonGModHammerStockMouseLeave(Sender: TObject);
    procedure ButtonGModHammerCustomClick(Sender: TObject);
    procedure ButtonGModHammerCustomMouseEnter(Sender: TObject);
    procedure ButtonGModHammerCustomMouseLeave(Sender: TObject);
    procedure ButtonEZ2HammerStockClick(Sender: TObject);
    procedure ButtonEZ2HammerStockMouseEnter(Sender: TObject);
    procedure ButtonEZ2HammerStockMouseLeave(Sender: TObject);
    procedure ButtonEZ2HammerCustomClick(Sender: TObject);
    procedure ButtonEZ2HammerCustomMouseEnter(Sender: TObject);
    procedure ButtonEZ2HammerCustomMouseLeave(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LauncherKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FHL2HammerStock: string;
    FHL2HammerStockArgs: string;
    FHL2HammerCustom: string;
    FHL2HammerCustomArgs: string;
    FGModHammerStock: string;
    FGModHammerStockArgs: string;
    FGModHammerCustom: string;
    FGModHammerCustomArgs: string;
    FEZ2HammerStock: string;
    FEZ2HammerStockArgs: string;
    FEZ2HammerCustom: string;
    FEZ2HammerCustomArgs: string;
    FFilePath: string;
    procedure AssignKeyHandler(AControl: TControl);
    procedure ClearButtonStatus(Sender: TObject);
    procedure LaunchHammer(const AExecutable, AArguments: string);
    procedure SetButtonStatus(AButton: TBitBtn; const AText: string);
  public
    procedure InitializeTarget;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  launcher_configuration,
  LCLType;

procedure TMainForm.FormCreate(Sender: TObject);
var
  Configuration: TLauncherConfiguration;
begin
  Configuration := LoadLauncherConfiguration(Application.ExeName);
  FHL2HammerStock := Configuration.HL2HammerStock;
  FHL2HammerStockArgs := Configuration.HL2HammerStockArgs;
  FHL2HammerCustom := Configuration.HL2HammerCustom;
  FHL2HammerCustomArgs := Configuration.HL2HammerCustomArgs;
  FGModHammerStock := Configuration.GModHammerStock;
  FGModHammerStockArgs := Configuration.GModHammerStockArgs;
  FGModHammerCustom := Configuration.GModHammerCustom;
  FGModHammerCustomArgs := Configuration.GModHammerCustomArgs;
  FEZ2HammerStock := Configuration.EZ2HammerStock;
  FEZ2HammerStockArgs := Configuration.EZ2HammerStockArgs;
  FEZ2HammerCustom := Configuration.EZ2HammerCustom;
  FEZ2HammerCustomArgs := Configuration.EZ2HammerCustomArgs;

  ButtonHL2HammerStock.Enabled := FileExists(FHL2HammerStock);
  ButtonHL2HammerCustom.Enabled := FileExists(FHL2HammerCustom);
  ButtonGModHammerStock.Enabled := FileExists(FGModHammerStock);
  ButtonGModHammerCustom.Enabled := FileExists(FGModHammerCustom);
  ButtonEZ2HammerStock.Enabled := FileExists(FEZ2HammerStock);
  ButtonEZ2HammerCustom.Enabled := FileExists(FEZ2HammerCustom);

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

procedure TMainForm.ButtonHL2HammerStockClick(Sender: TObject);
begin
  LaunchHammer(FHL2HammerStock, FHL2HammerStockArgs);
end;

procedure TMainForm.ButtonHL2HammerCustomClick(Sender: TObject);
begin
  LaunchHammer(FHL2HammerCustom, FHL2HammerCustomArgs);
end;

procedure TMainForm.ButtonGModHammerStockClick(Sender: TObject);
begin
  LaunchHammer(FGModHammerStock, FGModHammerStockArgs);
end;

procedure TMainForm.ButtonGModHammerCustomClick(Sender: TObject);
begin
  LaunchHammer(FGModHammerCustom, FGModHammerCustomArgs);
end;

procedure TMainForm.ButtonEZ2HammerStockClick(Sender: TObject);
begin
  LaunchHammer(FEZ2HammerStock, FEZ2HammerStockArgs);
end;

procedure TMainForm.ButtonEZ2HammerCustomClick(Sender: TObject);
begin
  LaunchHammer(FEZ2HammerCustom, FEZ2HammerCustomArgs);
end;

procedure TMainForm.ButtonHL2HammerStockMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonHL2HammerStock, 'Half-Life 2 Hammer');
end;

procedure TMainForm.ButtonHL2HammerStockMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonHL2HammerCustomMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonHL2HammerCustom, 'Half-Life 2 Hammer++');
end;

procedure TMainForm.ButtonHL2HammerCustomMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonGModHammerStockMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonGModHammerStock, 'Garry''s Mod Hammer');
end;

procedure TMainForm.ButtonGModHammerStockMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonGModHammerCustomMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonGModHammerCustom, 'Garry''s Mod Hammer++');
end;

procedure TMainForm.ButtonGModHammerCustomMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonEZ2HammerStockMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonEZ2HammerStock, 'Entropy: Zero 2 Hammer');
end;

procedure TMainForm.ButtonEZ2HammerStockMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.ButtonEZ2HammerCustomMouseEnter(Sender: TObject);
begin
  SetButtonStatus(ButtonEZ2HammerCustom, 'Entropy: Zero 2 Hammer++');
end;

procedure TMainForm.ButtonEZ2HammerCustomMouseLeave(Sender: TObject);
begin
  ClearButtonStatus(Sender);
end;

procedure TMainForm.LauncherKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_1, VK_NUMPAD1:
      if ButtonHL2HammerStock.Enabled then
        ButtonHL2HammerStock.Click;
    VK_2, VK_NUMPAD2:
      if ButtonHL2HammerCustom.Enabled then
        ButtonHL2HammerCustom.Click;
    VK_3, VK_NUMPAD3:
      if ButtonGModHammerStock.Enabled then
        ButtonGModHammerStock.Click;
    VK_4, VK_NUMPAD4:
      if ButtonGModHammerCustom.Enabled then
        ButtonGModHammerCustom.Click;
    VK_5, VK_NUMPAD5:
      if ButtonEZ2HammerStock.Enabled then
        ButtonEZ2HammerStock.Click;
    VK_6, VK_NUMPAD6:
      if ButtonEZ2HammerCustom.Enabled then
        ButtonEZ2HammerCustom.Click;
  end;
end;

procedure TMainForm.AssignKeyHandler(AControl: TControl);
var
  ChildIndex: Integer;
begin
  if AControl is TWinControl then begin
    TWinControl(AControl).OnKeyDown := @LauncherKeyDown;
    for ChildIndex := 0 to TWinControl(AControl).ControlCount - 1 do
      AssignKeyHandler(TWinControl(AControl).Controls[ChildIndex]);
  end;
end;

procedure TMainForm.ClearButtonStatus(Sender: TObject);
begin
  StatusBar.SimpleText := '';
end;

procedure TMainForm.LaunchHammer(const AExecutable, AArguments: string);
var
  HammerProcess: TProcess;
begin
  if not FileExists(AExecutable) then
    Exit;

  HammerProcess := TProcess.Create(nil);
  try
    HammerProcess.Executable := AExecutable;
    HammerProcess.Parameters.DelimitedText := AArguments;
    if FFilePath <> '' then
      HammerProcess.Parameters.Add(FFilePath);
    HammerProcess.Execute;
  finally
    HammerProcess.Free;
  end;

  Application.Terminate;
end;

procedure TMainForm.SetButtonStatus(AButton: TBitBtn; const AText: string);
begin
  AButton.Hint := AText;
  StatusBar.SimpleText := AText;
end;

end.
