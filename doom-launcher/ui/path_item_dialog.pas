unit path_item_dialog;

{$MODE objfpc}
{$H+}

interface

uses
  ButtonPanel,
  Forms,
  launcher_models,
  StdCtrls;

type
  TPathItemDialog = class(TForm)
    AbsoluteCheckBox: TCheckBox;
    BrowseButton: TButton;
    ButtonPanel1: TButtonPanel;
    DisplayNameEdit: TEdit;
    DisplayNameLabel: TLabel;
    PathEdit: TEdit;
    PathLabel: TLabel;
    procedure BrowseClick(Sender: TObject);
  private
    FSelectDirectory: Boolean;
  end;

function EditPathItem(
    const ATitle, ABaseDirectory: string;
    ASelectDirectory: Boolean;
    var ADisplayName: string;
    var AStoredPath: TStoredPath
): Boolean;

var
  PathItemDialog: TPathItemDialog;

implementation

{$R *.lfm}

uses
  Controls,
  Dialogs,
  path_service,
  SysUtils;

procedure TPathItemDialog.BrowseClick(Sender: TObject);
var
  DirectoryName: string;
  FileDialog: TOpenDialog;
begin
  if FSelectDirectory then begin
    DirectoryName := PathEdit.Text;
    if SelectDirectory('Select data folder', '', DirectoryName) then
      PathEdit.Text := DirectoryName;
  end
  else begin
    FileDialog := TOpenDialog.Create(Self);
    try
      FileDialog.Filter := 'Executable files|*.exe|All files|*.*';
      FileDialog.FileName := PathEdit.Text;
      if FileDialog.Execute then
        PathEdit.Text := FileDialog.FileName;
    finally
      FileDialog.Free;
    end;
  end;
end;

function EditPathItem(
    const ATitle, ABaseDirectory: string;
    ASelectDirectory: Boolean;
    var ADisplayName: string;
    var AStoredPath: TStoredPath
): Boolean;
var
  Dialog: TPathItemDialog;
  SelectedPath: string;
begin
  Result := False;
  Dialog := TPathItemDialog.Create(nil);
  try
    Dialog.ButtonPanel1.OKButton.Default := True;
    Dialog.ButtonPanel1.CancelButton.Cancel := True;
    Dialog.Caption := ATitle;
    Dialog.FSelectDirectory := ASelectDirectory;
    Dialog.DisplayNameEdit.Text := ADisplayName;
    if AStoredPath.Value <> '' then
      Dialog.PathEdit.Text := ResolveStoredPath(ABaseDirectory, AStoredPath);
    Dialog.AbsoluteCheckBox.Checked := AStoredPath.IsAbsolute;

    if Dialog.ShowModal <> mrOK then
      Exit;
    if Trim(Dialog.DisplayNameEdit.Text) = '' then begin
      MessageDlg('Display name is required.', mtError, [mbOK], 0);
      Exit;
    end;
    SelectedPath := ExpandFileName(Trim(Dialog.PathEdit.Text));
    if (ASelectDirectory and not DirectoryExists(SelectedPath)) or ((not ASelectDirectory) and not FileExists(SelectedPath)) then begin
      MessageDlg('The selected path does not exist.', mtError, [mbOK], 0);
      Exit;
    end;
    if (not Dialog.AbsoluteCheckBox.Checked) and not CanStoreRelative(ABaseDirectory, SelectedPath) then begin
      if MessageDlg('The selected path is on a different drive. Store it as an absolute path?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
        Exit;
      Dialog.AbsoluteCheckBox.Checked := True;
    end;
    ADisplayName := Trim(Dialog.DisplayNameEdit.Text);
    AStoredPath := CreateStoredPath(ABaseDirectory, SelectedPath, Dialog.AbsoluteCheckBox.Checked);
    Result := True;
  finally
    Dialog.Free;
  end;
end;

end.
