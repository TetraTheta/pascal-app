unit data_directories_dialog;

{$MODE objfpc}
{$H+}

interface

uses
  ButtonPanel,
  ExtCtrls,
  Forms,
  launcher_models,
  StdCtrls;

type
  TDataDirectoriesDialog = class(TForm)
    AddButton: TButton;
    ButtonPanel1: TButtonPanel;
    ControlsPanel: TPanel;
    EditButton: TButton;
    FList: TListBox;
    RemoveButton: TButton;
    procedure AddClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
  private
    FBaseDirectory: string;
    FChanged: Boolean;
    FSettings: TLauncherSettings;
    procedure Populate;
  end;

function ShowDataDirectoriesDialog(const ABaseDirectory: string; ASettings: TLauncherSettings): Boolean;

var
  DataDirectoriesDialog: TDataDirectoriesDialog;

implementation

{$R *.lfm}

uses
  Classes,
  Controls,
  Dialogs,
  path_item_dialog,
  SysUtils;

procedure TDataDirectoriesDialog.Populate;
var
  DataDirectory: TDataDirectory;
  EnvironmentPath: string;
  Index: Integer;
  Paths: TStringList;
begin
  FList.Clear;
  for Index := 0 to FSettings.DataDirectories.Count - 1 do begin
    DataDirectory := TDataDirectory(FSettings.DataDirectories[Index]);
    FList.Items.AddObject(DataDirectory.DisplayName + ' — ' + DataDirectory.DirectoryName.Value, DataDirectory);
  end;

  Paths := TStringList.Create;
  try
    Paths.Delimiter := PathSeparator;
    Paths.StrictDelimiter := True;
    Paths.DelimitedText := GetEnvironmentVariable('DOOMWADPATH');
    EnvironmentPath := GetEnvironmentVariable('DOOMWADDIR');
    if EnvironmentPath <> '' then
      Paths.Insert(0, EnvironmentPath);
    for Index := 0 to Paths.Count - 1 do
      if Trim(Paths[Index]) <> '' then
        FList.Items.AddObject('[Environment] ' + Paths[Index], nil);
  finally
    Paths.Free;
  end;
end;

procedure TDataDirectoriesDialog.AddClick(Sender: TObject);
var
  DataDirectory: TDataDirectory;
  DisplayName: string;
  DirectoryPath: TStoredPath;
begin
  DisplayName := 'WADs';
  DirectoryPath := StoredPath('', False);
  if not EditPathItem('Add Data Folder', FBaseDirectory, True, DisplayName, DirectoryPath) then
    Exit;
  DataDirectory := TDataDirectory.Create(DisplayName, DirectoryPath);
  FSettings.DataDirectories.Add(DataDirectory);
  FChanged := True;
  Populate;
end;

procedure TDataDirectoriesDialog.RemoveClick(Sender: TObject);
var
  DataDirectory: TObject;
begin
  if FList.ItemIndex < 0 then
    Exit;
  DataDirectory := FList.Items.Objects[FList.ItemIndex];
  if DataDirectory = nil then begin
    MessageDlg('Environment data folders are read-only.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Remove this data folder?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FSettings.DataDirectories.Remove(DataDirectory);
  FChanged := True;
  Populate;
end;

procedure TDataDirectoriesDialog.EditClick(Sender: TObject);
var
  DataDirectory: TDataDirectory;
  DisplayName: string;
  DirectoryPath: TStoredPath;
begin
  if FList.ItemIndex < 0 then
    Exit;
  DataDirectory := TDataDirectory(FList.Items.Objects[FList.ItemIndex]);
  if DataDirectory = nil then begin
    MessageDlg('Environment data folders are read-only.', mtInformation, [mbOK], 0);
    Exit;
  end;
  DisplayName := DataDirectory.DisplayName;
  DirectoryPath := DataDirectory.DirectoryName;
  if not EditPathItem('Edit Data Folder', FBaseDirectory, True, DisplayName, DirectoryPath) then
    Exit;
  DataDirectory.DisplayName := DisplayName;
  DataDirectory.DirectoryName := DirectoryPath;
  DataDirectory.StoreDiscoveredPathsAbsolute := DirectoryPath.IsAbsolute;
  FChanged := True;
  Populate;
end;

function ShowDataDirectoriesDialog(const ABaseDirectory: string; ASettings: TLauncherSettings): Boolean;
var
  Dialog: TDataDirectoriesDialog;
begin
  Dialog := TDataDirectoriesDialog.Create(nil);
  try
    Dialog.ButtonPanel1.CloseButton.Cancel := True;
    Dialog.FBaseDirectory := ABaseDirectory;
    Dialog.FSettings := ASettings;
    Dialog.Populate;
    Dialog.ShowModal;
    Result := Dialog.FChanged;
  finally
    Dialog.Free;
  end;
end;

end.
