unit launch_options_dialog;

{$mode objfpc}{$H+}

interface

uses
  ButtonPanel, Classes, Forms, launcher_models, Spin, StdCtrls;

type
  TLaunchOptionsDialog = class(TForm)
    ButtonPanel1: TButtonPanel;
    EnableMultiplayerCheckBox: TCheckBox;
    FastMonstersCheckBox: TCheckBox;
    HostEdit: TEdit;
    HostLabel: TLabel;
    HostRadioButton: TRadioButton;
    JoinRadioButton: TRadioButton;
    MapComboBox: TComboBox;
    MapLabel: TLabel;
    NoMonstersCheckBox: TCheckBox;
    PlayerCountEdit: TSpinEdit;
    PlayerCountLabel: TLabel;
    PortEdit: TSpinEdit;
    PortLabel: TLabel;
    RespawnMonstersCheckBox: TCheckBox;
    SkillComboBox: TComboBox;
    SkillLabel: TLabel;
  end;

function EditLaunchOptions(var AOptions: TLaunchOptions; AAvailableMaps: TStrings = nil): Boolean;

var
  LaunchOptionsDialog: TLaunchOptionsDialog;

implementation

{$R *.lfm}

uses
  Controls, Dialogs, launch_service, SysUtils;

function EditLaunchOptions(var AOptions: TLaunchOptions; AAvailableMaps: TStrings): Boolean;
var
  Dialog: TLaunchOptionsDialog;
  ErrorText: string;
  UpdatedOptions: TLaunchOptions;
begin
  Result := False;
  Dialog := TLaunchOptionsDialog.Create(nil);
  try
    Dialog.ButtonPanel1.OKButton.Caption := 'Apply';
    Dialog.ButtonPanel1.OKButton.Default := True;
    Dialog.ButtonPanel1.CancelButton.Cancel := True;
    if (AOptions.Skill >= 0) and (AOptions.Skill <= 5) then
      Dialog.SkillComboBox.ItemIndex := AOptions.Skill
    else
      Dialog.SkillComboBox.ItemIndex := 3;
    if AAvailableMaps <> nil then
      Dialog.MapComboBox.Items.Assign(AAvailableMaps);
    Dialog.MapComboBox.Text := AOptions.StartMap;
    Dialog.NoMonstersCheckBox.Checked := AOptions.NoMonsters;
    Dialog.FastMonstersCheckBox.Checked := AOptions.FastMonsters;
    Dialog.RespawnMonstersCheckBox.Checked := AOptions.RespawnMonsters;
    Dialog.EnableMultiplayerCheckBox.Checked := AOptions.EnableMultiplayer;
    Dialog.HostRadioButton.Checked := AOptions.HostGame;
    Dialog.JoinRadioButton.Checked := not AOptions.HostGame;
    Dialog.HostEdit.Text := AOptions.HostName;
    if (AOptions.Port >= 1) and (AOptions.Port <= 65535) then
      Dialog.PortEdit.Value := AOptions.Port
    else
      Dialog.PortEdit.Value := 10666;
    if (AOptions.PlayerCount >= 1) and (AOptions.PlayerCount <= 64) then
      Dialog.PlayerCountEdit.Value := AOptions.PlayerCount
    else
      Dialog.PlayerCountEdit.Value := 4;

    if Dialog.ShowModal <> mrOK then
      Exit;
    UpdatedOptions := AOptions;
    UpdatedOptions.EnableMultiplayer := Dialog.EnableMultiplayerCheckBox.Checked;
    UpdatedOptions.FastMonsters := Dialog.FastMonstersCheckBox.Checked;
    UpdatedOptions.HostGame := Dialog.HostRadioButton.Checked;
    UpdatedOptions.HostName := Trim(Dialog.HostEdit.Text);
    UpdatedOptions.NoMonsters := Dialog.NoMonstersCheckBox.Checked;
    UpdatedOptions.PlayerCount := Dialog.PlayerCountEdit.Value;
    UpdatedOptions.Port := Dialog.PortEdit.Value;
    UpdatedOptions.RespawnMonsters := Dialog.RespawnMonstersCheckBox.Checked;
    UpdatedOptions.Skill := Dialog.SkillComboBox.ItemIndex;
    UpdatedOptions.StartMap := Trim(Dialog.MapComboBox.Text);
    if not ValidateLaunchOptions(UpdatedOptions, ErrorText) then
    begin
      MessageDlg(ErrorText, mtError, [mbOK], 0);
      Exit;
    end;
    AOptions := UpdatedOptions;
    Result := True;
  finally
    Dialog.Free;
  end;
end;

end.
