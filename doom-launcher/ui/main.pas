unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, ComCtrls, Controls, ExtCtrls, Forms, Menus, StdCtrls, Interfaces, launcher_models;

type
  TMainForm = class;

  TWadScanThread = class(TThread)
  private
    FBaseDirectory: string;
    FCacheChanged: Boolean;
    FError: string;
    FResults: TObject;
    FSettings: TLauncherSettings;
  protected
    procedure Execute; override;
  public
    constructor Create(const ABaseDirectory: string; ASettings: TLauncherSettings);
    destructor Destroy; override;
    property CacheChanged: Boolean read FCacheChanged;
    property ErrorText: string read FError;
    property Results: TObject read FResults write FResults;
  end;

  TMainForm = class(TForm)
    AddEngineButton: TButton;
    AddSelectedButton: TButton;
    AvailableLabel: TLabel;
    BottomPanel: TPanel;
    ContentPanel: TPanel;
    DownButton: TButton;
    EditEngineButton: TButton;
    EngineGroup: TGroupBox;
    ExitAfterLaunchMenuItem: TMenuItem;
    ExitMenuItem: TMenuItem;
    ExportProfileMenuItem: TMenuItem;
    ExtraArgumentsLabel: TLabel;
    FAvailableFilter: TEdit;
    FAvailablePanel: TPanel;
    FAvailableWads: TListView;
    FEngineList: TListBox;
    FExtraArguments: TEdit;
    FileMenu: TMenuItem;
    FIWadList: TListBox;
    FLockedCheckBox: TCheckBox;
    FProfileList: TListBox;
    FRunButton: TButton;
    FSaveProfileButton: TButton;
    FSelectedFilter: TEdit;
    FSelectedPanel: TPanel;
    FSelectedWads: TListView;
    FStatusBar: TStatusBar;
    FTopPanel: TPanel;
    FTransferPanel: TPanel;
    ImportProfileMenuItem: TMenuItem;
    IWadGroup: TGroupBox;
    LaunchOptionsButton: TButton;
    MainMenu1: TMainMenu;
    ManageDataFoldersMenuItem: TMenuItem;
    MenuSeparator1: TMenuItem;
    MenuSeparator2: TMenuItem;
    MenuSeparator3: TMenuItem;
    NewProfileButton: TButton;
    ProfileGroup: TGroupBox;
    RefreshMenuItem: TMenuItem;
    RefreshWadsButton: TButton;
    RemoveEngineButton: TButton;
    RemoveProfileButton: TButton;
    RemoveSelectedButton: TButton;
    RenameProfileButton: TButton;
    SelectedLabel: TLabel;
    UpButton: TButton;
    procedure AddEngineClick(Sender: TObject);
    procedure AddWadClick(Sender: TObject);
    procedure AvailableFilterChange(Sender: TObject);
    procedure DataDirectoriesClick(Sender: TObject);
    procedure EditEngineClick(Sender: TObject);
    procedure EngineSelectionChange(Sender: TObject);
    procedure ExitAfterLaunchClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure ExportProfileClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ImportProfileClick(Sender: TObject);
    procedure IWadSelectionChange(Sender: TObject);
    procedure LaunchOptionsClick(Sender: TObject);
    procedure LockProfileClick(Sender: TObject);
    procedure MoveWadDownClick(Sender: TObject);
    procedure MoveWadUpClick(Sender: TObject);
    procedure NewProfileClick(Sender: TObject);
    procedure ProfileSelectionChange(Sender: TObject);
    procedure RefreshClick(Sender: TObject);
    procedure RemoveEngineClick(Sender: TObject);
    procedure RemoveProfileClick(Sender: TObject);
    procedure RemoveWadClick(Sender: TObject);
    procedure RenameProfileClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure RunMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure SaveProfileClick(Sender: TObject);
    procedure SelectedFilterChange(Sender: TObject);
    procedure TextProfileChange(Sender: TObject);
  private
    FAllowSave: Boolean;
    FBaseDirectory: string;
    FConfigFileName: string;
    FCurrentProfileIndex: Integer;
    FDirty: Boolean;
    FScanThread: TWadScanThread;
    FSettings: TLauncherSettings;
    FUpdating: Boolean;
    FWads: TObject;
    FWorkingProfile: TProfile;
    function CanEditProfile: Boolean;
    function CanLaunchProfile: Boolean;
    function ConfirmPendingChanges: Boolean;
    function FindWad(const APath: TStoredPath): TWadMetadata;
    function UniqueProfileName(const AName: string; AExceptIndex: Integer): Boolean;
    procedure ApplyWorkingProfile;
    procedure LoadWorkingProfile(AIndex: Integer);
    procedure MarkDirty;
    procedure PopulateAvailableWads;
    procedure PopulateEngines;
    procedure PopulateIWads;
    procedure PopulateProfiles;
    procedure PopulateSelectedWads(ASelectedModIndex: Integer = -1);
    procedure SaveSettings;
    procedure ScanFinished(Sender: TObject);
    procedure SetProfileControls;
    procedure StartScan;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  Contnrs, data_directories_dialog, Dialogs, launch_arguments_dialog, launch_options_dialog, launch_service, launcher_configuration, path_item_dialog, path_service, profile_service, SysUtils, wad_service;

constructor TWadScanThread.Create(const ABaseDirectory: string;
  ASettings: TLauncherSettings);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FBaseDirectory := ABaseDirectory;
  FSettings := ASettings;
end;

destructor TWadScanThread.Destroy;
begin
  FResults.Free;
  inherited Destroy;
end;

procedure TWadScanThread.Execute;
begin
  try
    FResults := ScanWads(FBaseDirectory, FSettings, FCacheChanged);
  except
    on E: Exception do
      FError := E.Message;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  BackupFileName: string;
  ErrorText: string;
begin
  FAllowSave := True;
  FBaseDirectory := IncludeTrailingPathDelimiter(ExtractFileDir(Application.ExeName));
  FConfigFileName := ChangeFileExt(Application.ExeName, '.ini');
  FCurrentProfileIndex := -1;
  FSettings := TLauncherSettings.Create;
  FWads := TObjectList.Create(True);
  FWorkingProfile := TProfile.Create;

  if not LoadLauncherSettings(FConfigFileName, FSettings, ErrorText) then
  begin
    if MessageDlg('The configuration could not be read:' + LineEnding + ErrorText + LineEnding + LineEnding + 'Back it up and start with empty settings?', mtError, [mbYes, mbNo], 0) = mrYes then
    begin
      try
        BackupFileName := BackupBrokenConfiguration(FConfigFileName);
        MessageDlg('The old configuration was moved to:' + LineEnding + BackupFileName, mtInformation, [mbOK], 0);
      except
        on E: Exception do
        begin
          FAllowSave := False;
          MessageDlg(E.Message, mtError, [mbOK], 0);
        end;
      end;
    end
    else
      FAllowSave := False;
  end;

  ExitAfterLaunchMenuItem.Checked := FSettings.ExitAfterLaunch;
  PopulateEngines;
  PopulateProfiles;
  LoadWorkingProfile(FSettings.SelectedProfileIndex);
  StartScan;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FWorkingProfile.Free;
  FWads.Free;
  FSettings.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FScanThread <> nil then
  begin
    MessageDlg('Please wait for the WAD scan to finish.', mtInformation, [mbOK], 0);
    CanClose := False;
    Exit;
  end;
  CanClose := ConfirmPendingChanges;
end;

procedure TMainForm.SaveSettings;
begin
  if not FAllowSave then
    Exit;
  try
    SaveLauncherSettings(FConfigFileName, FSettings);
  except
    on E: Exception do
      MessageDlg('Unable to save settings:' + LineEnding + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.PopulateEngines;
var
  Engine: TEngine;
  Index: Integer;
begin
  FEngineList.Clear;
  for Index := 0 to FSettings.Engines.Count - 1 do
  begin
    Engine := TEngine(FSettings.Engines[Index]);
    FEngineList.Items.AddObject(Engine.DisplayName + ' — ' + Engine.FileName.Value, Engine);
  end;
end;

procedure TMainForm.PopulateProfiles;
var
  Index: Integer;
  Profile: TProfile;
begin
  FProfileList.Clear;
  for Index := 0 to FSettings.Profiles.Count - 1 do
  begin
    Profile := TProfile(FSettings.Profiles[Index]);
    FProfileList.Items.AddObject(Profile.Name, Profile);
  end;
end;

procedure TMainForm.PopulateIWads;
var
  Index: Integer;
  Wad: TWadMetadata;
begin
  FIWadList.Clear;
  for Index := 0 to TObjectList(FWads).Count - 1 do
  begin
    Wad := TWadMetadata(TObjectList(FWads)[Index]);
    if Wad.IsIWad then
      FIWadList.Items.AddObject(Wad.DisplayName + ' — ' + Wad.FileName.Value, Wad);
  end;
end;

procedure TMainForm.PopulateAvailableWads;
var
  Index: Integer;
  Item: TListItem;
  SearchText: string;
  Wad: TWadMetadata;
begin
  FAvailableWads.Items.BeginUpdate;
  try
    FAvailableWads.Clear;
    SearchText := LowerCase(Trim(FAvailableFilter.Text));
    for Index := 0 to TObjectList(FWads).Count - 1 do
    begin
      Wad := TWadMetadata(TObjectList(FWads)[Index]);
      if Wad.IsIWad or ((SearchText <> '') and (Pos(SearchText, LowerCase(Wad.DisplayName + ' ' + Wad.FileName.Value)) = 0)) then
        Continue;
      Item := FAvailableWads.Items.Add;
      Item.Caption := Wad.DisplayName;
      Item.SubItems.Add(IntToStr(Wad.MapIds.Count));
      Item.SubItems.Add(Wad.FileName.Value);
      Item.Data := Wad;
    end;
  finally
    FAvailableWads.Items.EndUpdate;
  end;
end;

function TMainForm.FindWad(const APath: TStoredPath): TWadMetadata;
var
  Index: Integer;
  Wad: TWadMetadata;
begin
  Result := nil;
  for Index := 0 to TObjectList(FWads).Count - 1 do
  begin
    Wad := TWadMetadata(TObjectList(FWads)[Index]);
    if SameFileName(ResolveStoredPath(FBaseDirectory, Wad.FileName), ResolveStoredPath(FBaseDirectory, APath)) then
      Exit(Wad);
  end;
end;

procedure TMainForm.PopulateSelectedWads(ASelectedModIndex: Integer);
var
  Index: Integer;
  Item: TListItem;
  Path: TStoredPath;
  SearchText: string;
  Wad: TWadMetadata;
begin
  FSelectedWads.Items.BeginUpdate;
  try
    FSelectedWads.Clear;
    SearchText := LowerCase(Trim(FSelectedFilter.Text));
    for Index := 0 to FWorkingProfile.Mods.Count - 1 do
    begin
      Path := StoredPath(FWorkingProfile.Mods[Index], PtrInt(FWorkingProfile.Mods.Objects[Index]) <> 0);
      Wad := FindWad(Path);
      if (SearchText <> '') and (Pos(SearchText, LowerCase(Path.Value)) = 0) then
        Continue;
      Item := FSelectedWads.Items.Add;
      if Wad <> nil then
      begin
        Item.Caption := Wad.DisplayName;
        Item.SubItems.Add(IntToStr(Wad.MapIds.Count));
        Item.Data := Wad;
      end
      else
      begin
        Item.Caption := '[Missing] ' + ExtractFileName(Path.Value);
        Item.SubItems.Add('?');
      end;
      Item.SubItems.Add(Path.Value);
      Item.ImageIndex := Index;
      Item.Selected := Index = ASelectedModIndex;
    end;
  finally
    FSelectedWads.Items.EndUpdate;
  end;
end;

procedure TMainForm.LoadWorkingProfile(AIndex: Integer);
begin
  FCurrentProfileIndex := AIndex;
  FWorkingProfile.Free;
  if (AIndex >= 0) and (AIndex < FSettings.Profiles.Count) then
    FWorkingProfile := TProfile(FSettings.Profiles[AIndex]).Clone
  else
  begin
    FCurrentProfileIndex := -1;
    FWorkingProfile := TProfile.Create;
    FWorkingProfile.Name := '_unsorted';
  end;
  FDirty := False;
  ApplyWorkingProfile;
end;

procedure TMainForm.ApplyWorkingProfile;
var
  Engine: TEngine;
  Index: Integer;
  Wad: TWadMetadata;
begin
  FUpdating := True;
  try
    FProfileList.ItemIndex := FCurrentProfileIndex;
    FEngineList.ItemIndex := -1;
    for Index := 0 to FSettings.Engines.Count - 1 do
    begin
      Engine := TEngine(FSettings.Engines[Index]);
      if SameFileName(ResolveStoredPath(FBaseDirectory, Engine.FileName), ResolveStoredPath(FBaseDirectory, FWorkingProfile.EnginePath)) then
        FEngineList.ItemIndex := Index;
    end;
    FIWadList.ItemIndex := -1;
    for Index := 0 to FIWadList.Items.Count - 1 do
    begin
      Wad := TWadMetadata(FIWadList.Items.Objects[Index]);
      if SameFileName(ResolveStoredPath(FBaseDirectory, Wad.FileName), ResolveStoredPath(FBaseDirectory, FWorkingProfile.IWadPath)) then
        FIWadList.ItemIndex := Index;
    end;
    FExtraArguments.Text := FWorkingProfile.ExtraArguments;
    FLockedCheckBox.Checked := FWorkingProfile.Locked;
    PopulateSelectedWads;
    SetProfileControls;
  finally
    FUpdating := False;
  end;
end;

function TMainForm.CanLaunchProfile: Boolean;
var
  Index: Integer;
  ModPath: TStoredPath;
begin
  Result := (FWorkingProfile.EnginePath.Value <> '') and FileExists(ResolveStoredPath(FBaseDirectory, FWorkingProfile.EnginePath)) and (FWorkingProfile.IWadPath.Value <> '') and FileExists(ResolveStoredPath(FBaseDirectory, FWorkingProfile.IWadPath));
  if not Result then
    Exit;
  for Index := 0 to FWorkingProfile.Mods.Count - 1 do
  begin
    ModPath := StoredPath(FWorkingProfile.Mods[Index], PtrInt(FWorkingProfile.Mods.Objects[Index]) <> 0);
    if not FileExists(ResolveStoredPath(FBaseDirectory, ModPath)) then
      Exit(False);
  end;
end;

function TMainForm.CanEditProfile: Boolean;
begin
  Result := not FWorkingProfile.Locked;
  if not Result then
    MessageDlg('This profile is locked.', mtInformation, [mbOK], 0);
end;

procedure TMainForm.SetProfileControls;
var
  Editable: Boolean;
begin
  Editable := not FWorkingProfile.Locked;
  FEngineList.Enabled := Editable;
  FIWadList.Enabled := Editable;
  FAvailableWads.Enabled := Editable;
  FSelectedWads.Enabled := Editable;
  FExtraArguments.Enabled := Editable;
  FSaveProfileButton.Enabled := Editable and (FCurrentProfileIndex >= 0) and FDirty;
  FRunButton.Enabled := CanLaunchProfile;
  FLockedCheckBox.Enabled := FCurrentProfileIndex >= 0;
  if FDirty then
    Caption := 'Doom Launcher *'
  else
    Caption := 'Doom Launcher';
end;

procedure TMainForm.MarkDirty;
begin
  if FUpdating or FWorkingProfile.Locked then
    Exit;
  FDirty := True;
  SetProfileControls;
end;

procedure TMainForm.TextProfileChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FWorkingProfile.ExtraArguments := FExtraArguments.Text;
  MarkDirty;
end;

procedure TMainForm.EngineSelectionChange(Sender: TObject);
begin
  if FUpdating or (FEngineList.ItemIndex < 0) or not CanEditProfile then
    Exit;
  FWorkingProfile.EnginePath := TEngine(FEngineList.Items.Objects[FEngineList.ItemIndex]).FileName;
  MarkDirty;
end;

procedure TMainForm.IWadSelectionChange(Sender: TObject);
begin
  if FUpdating or (FIWadList.ItemIndex < 0) or not CanEditProfile then
    Exit;
  FWorkingProfile.IWadPath := TWadMetadata(FIWadList.Items.Objects[FIWadList.ItemIndex]).FileName;
  MarkDirty;
end;

procedure TMainForm.AddWadClick(Sender: TObject);
var
  Wad: TWadMetadata;
begin
  if (FAvailableWads.Selected = nil) or not CanEditProfile then
    Exit;
  Wad := TWadMetadata(FAvailableWads.Selected.Data);
  if FWorkingProfile.Mods.IndexOf(Wad.FileName.Value) >= 0 then
    Exit;
  FWorkingProfile.Mods.AddObject(Wad.FileName.Value, TObject(PtrInt(Ord(Wad.FileName.IsAbsolute))));
  MarkDirty;
  PopulateSelectedWads;
end;

procedure TMainForm.RemoveWadClick(Sender: TObject);
var
  ModIndex: Integer;
begin
  if (FSelectedWads.Selected = nil) or not CanEditProfile then
    Exit;
  ModIndex := FSelectedWads.Selected.ImageIndex;
  if (ModIndex >= 0) and (ModIndex < FWorkingProfile.Mods.Count) then
  begin
    FWorkingProfile.Mods.Delete(ModIndex);
    MarkDirty;
    PopulateSelectedWads;
  end;
end;

procedure TMainForm.MoveWadUpClick(Sender: TObject);
var
  Index: Integer;
begin
  if (FSelectedWads.Selected = nil) or not CanEditProfile then
    Exit;
  Index := FSelectedWads.Selected.ImageIndex;
  if Index > 0 then
  begin
    FWorkingProfile.Mods.Exchange(Index, Index - 1);
    MarkDirty;
    PopulateSelectedWads(Index - 1);
  end;
end;

procedure TMainForm.MoveWadDownClick(Sender: TObject);
var
  Index: Integer;
begin
  if (FSelectedWads.Selected = nil) or not CanEditProfile then
    Exit;
  Index := FSelectedWads.Selected.ImageIndex;
  if (Index >= 0) and (Index < FWorkingProfile.Mods.Count - 1) then
  begin
    FWorkingProfile.Mods.Exchange(Index, Index + 1);
    MarkDirty;
    PopulateSelectedWads(Index + 1);
  end;
end;

procedure TMainForm.AvailableFilterChange(Sender: TObject);
begin
  PopulateAvailableWads;
end;

procedure TMainForm.SelectedFilterChange(Sender: TObject);
begin
  PopulateSelectedWads;
end;

procedure TMainForm.AddEngineClick(Sender: TObject);
var
  DisplayName: string;
  FileName: TStoredPath;
begin
  DisplayName := 'UZDoom';
  FileName := StoredPath('', False);
  if EditPathItem('Add Engine', FBaseDirectory, False, DisplayName, FileName) then
  begin
    FSettings.Engines.Add(TEngine.Create(DisplayName, FileName));
    SaveSettings;
    PopulateEngines;
  end;
end;

procedure TMainForm.RemoveEngineClick(Sender: TObject);
var
  Engine: TEngine;
  Index: Integer;
begin
  if FEngineList.ItemIndex < 0 then
    Exit;
  Engine := TEngine(FEngineList.Items.Objects[FEngineList.ItemIndex]);
  for Index := 0 to FSettings.Profiles.Count - 1 do
    if SameFileName(ResolveStoredPath(FBaseDirectory, Engine.FileName), ResolveStoredPath(FBaseDirectory, TProfile(FSettings.Profiles[Index]).EnginePath)) then
    begin
      MessageDlg('This engine is used by a profile.', mtError, [mbOK], 0);
      Exit;
    end;
  if MessageDlg('Remove this engine?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FSettings.Engines.Remove(Engine);
  SaveSettings;
  PopulateEngines;
end;

procedure TMainForm.EditEngineClick(Sender: TObject);
var
  DisplayName: string;
  Engine: TEngine;
  FileName: TStoredPath;
  Index: Integer;
  OldFileName: TStoredPath;
  Profile: TProfile;
begin
  if FEngineList.ItemIndex < 0 then
    Exit;
  Engine := TEngine(FEngineList.Items.Objects[FEngineList.ItemIndex]);
  DisplayName := Engine.DisplayName;
  FileName := Engine.FileName;
  OldFileName := Engine.FileName;
  if not EditPathItem('Edit Engine', FBaseDirectory, False, DisplayName, FileName) then
    Exit;
  Engine.DisplayName := DisplayName;
  Engine.FileName := FileName;
  for Index := 0 to FSettings.Profiles.Count - 1 do
  begin
    Profile := TProfile(FSettings.Profiles[Index]);
    if SameFileName(ResolveStoredPath(FBaseDirectory, Profile.EnginePath), ResolveStoredPath(FBaseDirectory, OldFileName)) then
      Profile.EnginePath := FileName;
  end;
  if SameFileName(ResolveStoredPath(FBaseDirectory, FWorkingProfile.EnginePath), ResolveStoredPath(FBaseDirectory, OldFileName)) then
    FWorkingProfile.EnginePath := FileName;
  SaveSettings;
  PopulateEngines;
  ApplyWorkingProfile;
end;

function TMainForm.UniqueProfileName(const AName: string;
  AExceptIndex: Integer): Boolean;
var
  Index: Integer;
  SanitizedName: string;
begin
  Result := False;
  SanitizedName := SanitizeDirectoryName(AName);
  for Index := 0 to FSettings.Profiles.Count - 1 do
    if (Index <> AExceptIndex) and (SameText(TProfile(FSettings.Profiles[Index]).Name, AName) or SameText(SanitizeDirectoryName(TProfile(FSettings.Profiles[Index]).Name), SanitizedName)) then
      Exit;
  Result := Trim(AName) <> '';
end;

procedure TMainForm.NewProfileClick(Sender: TObject);
var
  ProfileName: string;
  Profile: TProfile;
begin
  if not ConfirmPendingChanges then
    Exit;
  ProfileName := 'New Profile';
  if not InputQuery('New Profile', 'Profile name', ProfileName) then
    Exit;
  if not UniqueProfileName(ProfileName, -1) then
  begin
    MessageDlg('The profile name or save folder is already in use.', mtError, [mbOK], 0);
    Exit;
  end;
  Profile := FWorkingProfile.Clone;
  Profile.Name := Trim(ProfileName);
  Profile.Locked := False;
  FSettings.Profiles.Add(Profile);
  PopulateProfiles;
  FSettings.SelectedProfileIndex := FSettings.Profiles.Count - 1;
  SaveSettings;
  LoadWorkingProfile(FSettings.SelectedProfileIndex);
end;

procedure TMainForm.RenameProfileClick(Sender: TObject);
var
  ProfileName: string;
  Profile: TProfile;
begin
  if (FCurrentProfileIndex < 0) or FWorkingProfile.Locked then
    Exit;
  if not ConfirmPendingChanges then
    Exit;
  Profile := TProfile(FSettings.Profiles[FCurrentProfileIndex]);
  ProfileName := Profile.Name;
  if not InputQuery('Rename Profile', 'Profile name', ProfileName) then
    Exit;
  if not UniqueProfileName(ProfileName, FCurrentProfileIndex) then
  begin
    MessageDlg('The profile name or save folder is already in use.', mtError, [mbOK], 0);
    Exit;
  end;
  Profile.Name := Trim(ProfileName);
  SaveSettings;
  PopulateProfiles;
  LoadWorkingProfile(FCurrentProfileIndex);
end;

procedure TMainForm.RemoveProfileClick(Sender: TObject);
begin
  if FCurrentProfileIndex < 0 then
    Exit;
  if FWorkingProfile.Locked then
  begin
    MessageDlg('Unlock the profile before removing it.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Remove this profile? Save files will be kept.', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FSettings.Profiles.Delete(FCurrentProfileIndex);
  FSettings.SelectedProfileIndex := -1;
  SaveSettings;
  PopulateProfiles;
  LoadWorkingProfile(-1);
end;

procedure TMainForm.LockProfileClick(Sender: TObject);
var
  Profile: TProfile;
begin
  if FUpdating or (FCurrentProfileIndex < 0) then
    Exit;
  if not ConfirmPendingChanges then
  begin
    FUpdating := True;
    FLockedCheckBox.Checked := FWorkingProfile.Locked;
    FUpdating := False;
    Exit;
  end;
  Profile := TProfile(FSettings.Profiles[FCurrentProfileIndex]);
  Profile.Locked := FLockedCheckBox.Checked;
  SaveSettings;
  LoadWorkingProfile(FCurrentProfileIndex);
end;

procedure TMainForm.SaveProfileClick(Sender: TObject);
begin
  if (FCurrentProfileIndex < 0) or FWorkingProfile.Locked then
    Exit;
  TProfile(FSettings.Profiles[FCurrentProfileIndex]).Assign(FWorkingProfile);
  SaveSettings;
  FDirty := False;
  SetProfileControls;
  PopulateProfiles;
end;

function TMainForm.ConfirmPendingChanges: Boolean;
var
  Answer: TModalResult;
begin
  Result := True;
  if not FDirty or (FCurrentProfileIndex < 0) then
    Exit;
  Answer := MessageDlg('Save changes to the current profile?', mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if Answer = mrCancel then
    Exit(False);
  if Answer = mrYes then
  begin
    SaveProfileClick(Self);
    Result := not FDirty;
  end
  else
    FDirty := False;
end;

procedure TMainForm.ProfileSelectionChange(Sender: TObject);
var
  NewIndex: Integer;
begin
  if FUpdating then
    Exit;
  NewIndex := FProfileList.ItemIndex;
  if not ConfirmPendingChanges then
  begin
    FUpdating := True;
    FProfileList.ItemIndex := FCurrentProfileIndex;
    FUpdating := False;
    Exit;
  end;
  FSettings.SelectedProfileIndex := NewIndex;
  SaveSettings;
  LoadWorkingProfile(NewIndex);
end;

procedure TMainForm.DataDirectoriesClick(Sender: TObject);
begin
  if ShowDataDirectoriesDialog(FBaseDirectory, FSettings) then
  begin
    SaveSettings;
    StartScan;
  end;
end;

procedure TMainForm.RefreshClick(Sender: TObject);
begin
  StartScan;
end;

procedure TMainForm.StartScan;
begin
  if FScanThread <> nil then
    Exit;
  FStatusBar.SimpleText := 'Scanning WAD folders...';
  Enabled := False;
  FScanThread := TWadScanThread.Create(FBaseDirectory, FSettings);
  FScanThread.OnTerminate := @ScanFinished;
  FScanThread.Start;
end;

procedure TMainForm.ScanFinished(Sender: TObject);
var
  ScanThread: TWadScanThread;
begin
  ScanThread := TWadScanThread(Sender);
  FScanThread := nil;
  Enabled := True;
  if ScanThread.ErrorText <> '' then
    MessageDlg('WAD scan failed:' + LineEnding + ScanThread.ErrorText, mtError, [mbOK], 0)
  else if ScanThread.Results <> nil then
  begin
    FWads.Free;
    FWads := ScanThread.Results;
    ScanThread.Results := nil;
    if ScanThread.CacheChanged then
      SaveSettings;
    PopulateIWads;
    PopulateAvailableWads;
    ApplyWorkingProfile;
    FStatusBar.SimpleText := Format('%d WAD files found.', [TObjectList(FWads).Count]);
  end;
end;

procedure TMainForm.LaunchOptionsClick(Sender: TObject);
var
  AvailableMaps: TStringList;
  Index: Integer;
  ModPath: TStoredPath;
  Wad: TWadMetadata;
begin
  if not CanEditProfile then
    Exit;
  AvailableMaps := TStringList.Create;
  try
    AvailableMaps.Sorted := True;
    AvailableMaps.Duplicates := dupIgnore;
    Wad := FindWad(FWorkingProfile.IWadPath);
    if Wad <> nil then
      AvailableMaps.AddStrings(Wad.MapIds);
    for Index := 0 to FWorkingProfile.Mods.Count - 1 do
    begin
      ModPath := StoredPath(FWorkingProfile.Mods[Index], PtrInt(FWorkingProfile.Mods.Objects[Index]) <> 0);
      Wad := FindWad(ModPath);
      if Wad <> nil then
        AvailableMaps.AddStrings(Wad.MapIds);
    end;
    if EditLaunchOptions(FWorkingProfile.Options, AvailableMaps) then
      MarkDirty;
  finally
    AvailableMaps.Free;
  end;
end;

procedure TMainForm.RunClick(Sender: TObject);
var
  ErrorText: string;
begin
  if (FCurrentProfileIndex < 0) and (MessageDlg('No profile is selected. Saves will be stored in saves\_unsorted. Continue?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  if not LaunchProfile(FBaseDirectory, FWorkingProfile, ErrorText) then
  begin
    MessageDlg(ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  if FSettings.ExitAfterLaunch then
    Close;
end;

procedure TMainForm.RunMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Arguments: TStringList;
  SaveDirectory: string;
begin
  if Button <> mbRight then
    Exit;
  SaveDirectory := IncludeTrailingPathDelimiter(FBaseDirectory) + 'saves' + DirectorySeparator + SanitizeDirectoryName(FWorkingProfile.Name);
  try
    Arguments := BuildLaunchArguments(FBaseDirectory, SaveDirectory, FWorkingProfile);
    try
      ShowLaunchArgumentsDialog(Arguments);
    finally
      Arguments.Free;
    end;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.ExitAfterLaunchClick(Sender: TObject);
begin
  FSettings.ExitAfterLaunch := TMenuItem(Sender).Checked;
  SaveSettings;
end;

procedure TMainForm.ExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.ExportProfileClick(Sender: TObject);
var
  Dialog: TSaveDialog;
begin
  if FCurrentProfileIndex < 0 then
  begin
    MessageDlg('Select a profile first.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not ConfirmPendingChanges then
    Exit;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.DefaultExt := 'doom-profile.ini';
    Dialog.Filter := 'Doom Launcher profile|*.doom-profile.ini';
    Dialog.FileName := TProfile(FSettings.Profiles[FCurrentProfileIndex]).Name + '.doom-profile.ini';
    if Dialog.Execute then
      ExportProfile(Dialog.FileName, TProfile(FSettings.Profiles[FCurrentProfileIndex]));
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.ImportProfileClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  ImportedProfile: TProfile;
  Unresolved: TStringList;
begin
  if not ConfirmPendingChanges then
    Exit;
  Dialog := TOpenDialog.Create(Self);
  Unresolved := TStringList.Create;
  try
    Dialog.Filter := 'Doom Launcher profile|*.doom-profile.ini|INI files|*.ini';
    if not Dialog.Execute then
      Exit;
    try
      ImportedProfile := ImportProfile(Dialog.FileName, FBaseDirectory, FSettings.Engines, TObjectList(FWads), Unresolved);
      if not UniqueProfileName(ImportedProfile.Name, -1) then
        ImportedProfile.Name := ImportedProfile.Name + ' (Imported)';
      if not UniqueProfileName(ImportedProfile.Name, -1) then
      begin
        ImportedProfile.Free;
        MessageDlg('A profile with the imported name already exists.', mtError, [mbOK], 0);
        Exit;
      end;
      FSettings.Profiles.Add(ImportedProfile);
      FSettings.SelectedProfileIndex := FSettings.Profiles.Count - 1;
      SaveSettings;
      PopulateProfiles;
      LoadWorkingProfile(FSettings.SelectedProfileIndex);
      if Unresolved.Count > 0 then
        MessageDlg('The profile was imported, but these references are unresolved:' + LineEnding + Unresolved.Text, mtWarning, [mbOK], 0);
    except
      on E: Exception do
        MessageDlg('Unable to import the profile:' + LineEnding + E.Message, mtError, [mbOK], 0);
    end;
  finally
    Unresolved.Free;
    Dialog.Free;
  end;
end;

end.
