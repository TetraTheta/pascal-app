unit main_form;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, StdCtrls, Grids, ComCtrls, ExtCtrls, Menus, Dialogs, ShlObj, optimizer_configuration, language_service, optimizer_service, runtime_resource;

type
  TMainForm = class(TForm)
    MainMenu: TMainMenu;
    AddFilesButton: TRuntimeResourceSpeedButton;
    AddFolderButton: TRuntimeResourceSpeedButton;
    RemoveButton: TRuntimeResourceSpeedButton;
    ClearButton: TRuntimeResourceSpeedButton;
    OptimizeButton: TRuntimeResourceSpeedButton;
    StopButton: TRuntimeResourceSpeedButton;
    OptionsButton: TRuntimeResourceSpeedButton;
    AddFilesItem: TMenuItem;
    AddFolderItem: TMenuItem;
    OpenItem: TMenuItem;
    OpenFolderItem: TMenuItem;
    RemoveItem: TMenuItem;
    ClearItem: TMenuItem;
    ExitItem: TMenuItem;
    OptimizeItem: TMenuItem;
    StopItem: TMenuItem;
    OptionsItem: TMenuItem;
    InformationItem: TMenuItem;
    AboutItem: TMenuItem;
    ContextOptimizeItem: TMenuItem;
    ContextStopItem: TMenuItem;
    ContextOptionsItem: TMenuItem;
    ContextRemoveItem: TMenuItem;
    ContextClearItem: TMenuItem;
    ContextOpenItem: TMenuItem;
    ContextOpenFolderItem: TMenuItem;
    ContextAboutItem: TMenuItem;
    ContextInformationItem: TMenuItem;
    ContextMenu: TPopupMenu;
    FileMenu: TMenuItem;
    OptimizeMenu: TMenuItem;
    OptionsMenu: TMenuItem;
    HelpMenu: TMenuItem;
    FToolBar: TPanel;
    BottomPanel: TPanel;
    FGrid: TStringGrid;
    FProgress: TProgressBar;
    FStatus: TLabel;
    FTimer: TTimer;
  private
    FConfiguration: TOptimizerConfiguration;
    FLanguage: TLanguageService;
    FService: TOptimizerService;
    FInstanceMutex: THandle;
    FOptimizing: Boolean;
    FCommandLineMode: Boolean;
    FStartupTick: QWord;
    FStartedTick: QWord;
    FSummary: string;
    FSortColumn: Integer;
    FSortDescending: Boolean;
    FTaskbar: ITaskBarList3;
    FComInitialized: Boolean;
  published
    procedure AboutClick(Sender: TObject);
    procedure AddFilesClick(Sender: TObject);
    procedure AddFolderClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridDblClick(Sender: TObject);
    procedure GridHeaderClick(Sender: TObject; IsColumn: Boolean; Index: Integer);
    procedure GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GridResize(Sender: TObject);
    procedure InformationClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure OpenFolderClick(Sender: TObject);
    procedure OptimizeClick(Sender: TObject);
    procedure OptionsClick(Sender: TObject);
    procedure RefreshGrid(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
  private
    procedure AddPath(const APath: string);
    procedure ApplyCommandLineOptions;
    procedure LoadSavedList;
    procedure RefreshCaptions;
    procedure SaveWindow;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}
{$R ../resource/images.rc}

uses
  SysUtils, Windows, FileUtil, LCLIntf, IniFiles, Clipbrd, options_form, ComObj, ActiveX, ShellApi;

type
  TOptimizerHintWindow = class(THintWindow)
  public
    function CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect; override;
  end;

const
  ES_CONTINUOUS = $80000000;
  ES_SYSTEM_REQUIRED = $00000001;

function NumberText(const AValue: Int64): string;
var
  Position: Integer;
begin
  Result := IntToStr(AValue);
  Position := Length(Result) - 2;
  while Position > 1 do
  begin
    Insert(',', Result, Position);
    Dec(Position, 3);
  end;
end;

function ElapsedText(const AMilliseconds: QWord): string;
var
  Seconds: QWord;
begin
  Seconds := AMilliseconds div 1000;
  Result := Format('%.2d:%.2d', [(Seconds div 60) mod 60, Seconds mod 60]);
  if Seconds >= 3600 then
    Result := IntToStr(Seconds div 3600) + ':' + Result;
end;

function TOptimizerHintWindow.CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect;
var
  TextSize: TSize;
begin
  Result := inherited CalcHintRect(MaxWidth, AHint, AData);
  TextSize := Canvas.TextExtent(AHint);
  if TextSize.CX + 16 <= MaxWidth then
  begin
    // LCL can measure a wrapped hint narrower than the text drawn on Win32.
    Result.Right := Max(Result.Right, TextSize.CX + 16);
    Result.Bottom := TextSize.CY + 8;
  end;
end;

function SetThreadExecutionState(AFlags: DWORD): DWORD;
  stdcall; external 'kernel32.dll' name 'SetThreadExecutionState';

function ShutdownWindows: Boolean;
var
  Privileges: TTokenPrivileges;
  Token: THandle;
begin
  Result := False;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, Token) then
    Exit;
  try
    if not LookupPrivilegeValue(nil, 'SeShutdownPrivilege', Privileges.Privileges[0].Luid) then
      Exit;
    Privileges.PrivilegeCount := 1;
    Privileges.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
    AdjustTokenPrivileges(Token, False, @Privileges, 0, PTokenPrivileges(nil), PDWord(nil));
    if GetLastError <> ERROR_SUCCESS then
      Exit;
    Result := ExitWindowsEx(EWX_SHUTDOWN or EWX_FORCE or $00400000, 0);
  finally
    CloseHandle(Token);
  end;
end;

procedure TMainForm.ApplyCommandLineOptions;
var
  Argument, Key, Value: string;
  ArgumentIndex, OptionIndex, Separator, Number: Integer;
  Spec: TOptionSpec;
begin
  for ArgumentIndex := 1 to ParamCount do
  begin
    Argument := ParamStr(ArgumentIndex);
    if (Length(Argument) < 3) or (Argument[1] <> '/') then
      Continue;
    Separator := Pos('=', Argument);
    if Separator < 3 then
      Continue;
    Key := Copy(Argument, 2, Separator - 2);
    Value := Copy(Argument, Separator + 1, MaxInt);
    for OptionIndex := 0 to OptionCount - 1 do
    begin
      Spec := OptionSpec(OptionIndex);
      if SameText(Key, Spec.Name) or SameText(Key, Spec.Section + Spec.Name) then
      begin
        if ((Spec.Kind = okBoolean) and not (SameText(Value, 'true') or SameText(Value, 'false'))) or ((Spec.Kind = okInteger) and not TryStrToInt(Value, Number)) then
          raise EConvertError.CreateFmt('Invalid command-line value: %s', [Argument]);
        FConfiguration.SetText(Spec.Section, Spec.Name, Value);
        Break;
      end;
    end;
  end;
end;

constructor TMainForm.Create(AOwner: TComponent);
var
  Index, LeftPosition, TopPosition: Integer;
begin
  inherited Create(AOwner);
  HintWindowClass := TOptimizerHintWindow;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  OnCloseQuery := @FormCloseQuery;
  FSortColumn := -1;
  FConfiguration := TOptimizerConfiguration.Create(ParamStr(0));
  ApplyCommandLineOptions;
  FLanguage := TLanguageService.Create(ParamStr(0), FConfiguration.GetText('General', 'Language'));
  if not FConfiguration.GetBoolean('General', 'AllowMultipleInstances') then
  begin
    SetLastError(0);
    FInstanceMutex := CreateMutexW(nil, False, 'FileOptimizer');
    if ((FInstanceMutex <> 0) and (GetLastError = ERROR_ALREADY_EXISTS)) or ((FInstanceMutex = 0) and (GetLastError = ERROR_ACCESS_DENIED)) then
    begin
      if MessageDlg(FLanguage.Text('AlreadyRunning', 'FileOptimizer is already running. Open another window?'), mtConfirmation, [mbYes, mbNo], 0) = mrNo then
        Application.Terminate;
    end;
  end;
  FService := TOptimizerService.Create(FConfiguration, ParamStr(0));
  FComInitialized := CoInitialize(nil) >= 0;
  if FComInitialized then
    try
      FTaskbar := CreateComObject(CLSID_TaskbarList) as ITaskBarList3;
      FTaskbar.HrInit;
    except
      FTaskbar := nil;
    end;
  Caption := 'FileOptimizer';
  Width := Max(480, FConfiguration.GetInteger('Window', 'Width'));
  Height := Max(280, FConfiguration.GetInteger('Window', 'Height'));
  LeftPosition := FConfiguration.GetInteger('Window', 'Left');
  TopPosition := FConfiguration.GetInteger('Window', 'Top');
  if (LeftPosition <> -1) and (TopPosition <> -1) then
  begin
    Left := LeftPosition;
    Top := TopPosition;
  end
  else
    Position := poScreenCenter;
  Constraints.MinWidth := 480;
  Constraints.MinHeight := 280;
  RefreshCaptions;
  if FConfiguration.GetBoolean('Window', 'Maximized') then
    WindowState := wsMaximized;
  if FConfiguration.GetBoolean('General', 'AlwaysOnTop') then
    FormStyle := fsStayOnTop;
  AllowDropFiles := True;
  OnDropFiles := @FormDropFiles;
  GridResize(FGrid);
  FToolBar.Visible := True;
  LoadSavedList;
  FCommandLineMode := False;
  for Index := 1 to ParamCount do
    if (ParamStr(Index) <> '') and (ParamStr(Index)[1] <> '/') then
      FCommandLineMode := True;
  FStartupTick := GetTickCount64;
  SetPriorityClass(GetCurrentProcess, FConfiguration.GetInteger('General', 'ProcessPriority'));
end;

procedure TMainForm.LoadSavedList;
var
  Index: Integer;
  Saved: TMemIniFile;
begin
  if not FConfiguration.GetBoolean('General', 'PersistentGrid') then
    Exit;
  Saved := TMemIniFile.Create(FConfiguration.Path);
  try
    for Index := 1 to Saved.ReadInteger('Grid', 'Count', 0) do
      AddPath(Saved.ReadString('Grid', 'File' + IntToStr(Index), ''));
  finally
    Saved.Free;
  end;
end;

destructor TMainForm.Destroy;
begin
  if Assigned(FTaskbar) then
    FTaskbar.SetProgressState(Handle, TBPF_NOPROGRESS);
  FTaskbar := nil;
  if FComInitialized then
    CoUninitialize;
  if Assigned(FConfiguration) then
    SaveWindow;
  FService.Free;
  FLanguage.Free;
  FConfiguration.Free;
  if FInstanceMutex <> 0 then
    CloseHandle(FInstanceMutex);
  inherited Destroy;
end;

procedure TMainForm.AboutClick(Sender: TObject);
begin
  MessageDlg('FileOptimizer' + LineEnding + 'File optimization for Windows.', mtInformation, [mbOK], 0);
end;

procedure TMainForm.InformationClick(Sender: TObject);
begin
  MessageDlg(FLanguage.Text('Information', 'Supported formats') + LineEnding + 'AVIF, BMP, CSS, DLL, EXE, FLAC, GIF, GZ, HTML, ICO, JPEG, JP2, JXL, JS, LUA, MIME, MKV, MNG, MP3, MP4, OBJ, OGG, OGV, OLE, PCX, PDF, PNG, SQLite, SWF, TAR, TGA, TIFF, WAV, WEBP, XML, ZIP, 7Z', mtInformation, [mbOK], 0);
end;

procedure TMainForm.AddPath(const APath: string);
var
  Search: TSearchRec;
begin
  if FileExists(APath) then
  begin
    FService.AddFile(APath);
    FSummary := '';
    Exit;
  end;
  if not DirectoryExists(APath) then
    Exit;
  if (GetFileAttributesW(PWideChar(UnicodeString(APath))) and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, Search) <> 0 then
    Exit;
  try
    repeat
      if (Search.Name = '.') or (Search.Name = '..') then
        Continue;
      if (Search.Attr and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
        Continue;
      if (Search.Attr and faDirectory) <> 0 then
        AddPath(IncludeTrailingPathDelimiter(APath) + Search.Name)
      else
        FService.AddFile(IncludeTrailingPathDelimiter(APath) + Search.Name);
    until FindNext(Search) <> 0;
  finally
    SysUtils.FindClose(Search);
  end;
end;

procedure TMainForm.GridHeaderClick(Sender: TObject; IsColumn: Boolean; Index: Integer);
begin
  if FOptimizing or not IsColumn or (FService.Count < 2) then
    Exit;
  if FSortColumn = Index then
    FSortDescending := not FSortDescending
  else
    FSortDescending := False;
  FSortColumn := Index;
  FService.SortByColumn(Index, FSortDescending);
  RefreshGrid(Self);
end;

procedure TMainForm.GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Column, Row: Integer;
begin
  FGrid.MouseToCell(X, Y, Column, Row);
  if (Column >= 0) and (Row >= 0) and (Column < FGrid.ColCount) and (Row < FGrid.RowCount) then
    FGrid.Hint := FGrid.Cells[Column, Row];
end;

procedure TMainForm.GridDblClick(Sender: TObject);
begin
  if FGrid.Col = 0 then
    OpenClick(Sender);
end;

procedure TMainForm.OpenClick(Sender: TObject);
begin
  if FOptimizing or (FGrid.Row < 1) or (FGrid.Row > FService.Count) then
    Exit;
  ShellExecuteW(Handle, 'open', PWideChar(UnicodeString(FService.Item(FGrid.Row - 1).FileName)), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.OpenFolderClick(Sender: TObject);
begin
  if FOptimizing or (FGrid.Row < 1) or (FGrid.Row > FService.Count) then
    Exit;
  ShellExecuteW(Handle, 'open', PWideChar(UnicodeString(ExtractFileDir(FService.Item(FGrid.Row - 1).FileName))), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Index: Integer;
  Lines: TStringList;
begin
  if FOptimizing then
    Exit;
  if (Key = VK_DELETE) and (Shift = []) then
    RemoveClick(Sender)
  else if (Key = VK_F5) and (Shift = [ssCtrl]) then
  begin
    FService.RemoveDone;
    FService.RefreshSizes;
    FSummary := '';
  end
  else if (Key = VK_F5) and (Shift = []) then
    FService.RefreshSizes
  else if (ssCtrl in Shift) and not (ssAlt in Shift) and (Key in [Ord('C'), Ord('X'), Ord('V')]) then
  begin
    if Key = Ord('V') then
    begin
      Lines := TStringList.Create;
      try
        Lines.Text := Clipboard.AsText;
        if Lines.Count > 0 then
        begin
          FService.Clear;
          FSummary := '';
          for Index := 0 to Lines.Count - 1 do
            AddPath(Trim(Lines[Index]));
        end;
      finally
        Lines.Free;
      end;
    end
    else
    begin
      Lines := TStringList.Create;
      try
        for Index := 0 to FService.Count - 1 do
          Lines.Add(FService.Item(Index).FileName);
        Clipboard.AsText := Lines.Text;
      finally
        Lines.Free;
      end;
      if Key = Ord('X') then
      begin
        FService.Clear;
        FSummary := '';
      end;
    end;
  end
  else
    Exit;
  Key := 0;
  RefreshGrid(Self);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not FOptimizing then
    Exit;
  CanClose := MessageDlg(FLanguage.Text('StopAndExit', 'Optimization is still running. Stop and exit?'), mtConfirmation, [mbYes, mbNo], 0) = mrYes;
  if CanClose then
  begin
    FService.Stop;
    FOptimizing := False;
    if FConfiguration.GetBoolean('General', 'DisableSleep') then
      SetThreadExecutionState(ES_CONTINUOUS);
  end;
end;

procedure TMainForm.ExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.AddFilesClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  Index: Integer;
begin
  if FOptimizing then
    Exit;
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Options := Dialog.Options + [ofAllowMultiSelect, ofFileMustExist];
    if Dialog.Execute then
      for Index := 0 to Dialog.Files.Count - 1 do
        AddPath(Dialog.Files[Index]);
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.AddFolderClick(Sender: TObject);
var
  Directory: string;
begin
  if FOptimizing then
    Exit;
  Directory := '';
  if SelectDirectory(FLanguage.Text('AddFolder', 'Add folder'), '', Directory) then
    AddPath(Directory);
end;

procedure TMainForm.FormDropFiles(Sender: TObject; const FileNames: array of string);
var
  FileName: string;
begin
  if FOptimizing then
    Exit;
  for FileName in FileNames do
    AddPath(FileName);
  RefreshGrid(Self);
end;

procedure TMainForm.GridResize(Sender: TObject);
begin
  FGrid.ColWidths[0] := Max(120, FGrid.ClientWidth - FGrid.ColWidths[1] - FGrid.ColWidths[2] - FGrid.ColWidths[3] - FGrid.ColWidths[4] - FGrid.ColCount * FGrid.GridLineWidth - 2);
end;

procedure TMainForm.OptimizeClick(Sender: TObject);
var
  Search: TSearchRec;
begin
  if FOptimizing or (FService.Count = 0) then
    Exit;
  if not DirectoryExists(FService.PluginDirectory) then
  begin
    MessageDlg(FLanguage.Text('NoPlugins', 'The plugin folder was not found.'), mtError, [mbOK], 0);
    Exit;
  end;
  if FindFirst(IncludeTrailingPathDelimiter(FService.PluginDirectory) + '*.exe', faAnyFile, Search) <> 0 then
  begin
    MessageDlg(FLanguage.Text('NoPluginPrograms', 'No plugin programs were found in the plugin folder.') + LineEnding + FService.PluginDirectory, mtError, [mbOK], 0);
    Exit;
  end;
  SysUtils.FindClose(Search);
  if FConfiguration.GetBoolean('General', 'DisableSleep') then
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED);
  FService.Start;
  FOptimizing := True;
  FStartedTick := GetTickCount64;
  FSummary := '';
end;

procedure TMainForm.OptionsClick(Sender: TObject);
var
  Dialog: TOptionsForm;
begin
  Dialog := TOptionsForm.CreateOptions(Self, FConfiguration, FLanguage, FOptimizing);
  try
    if (Dialog.ShowModal = mrOk) and not FOptimizing then
    begin
      FLanguage.Free;
      FLanguage := TLanguageService.Create(ParamStr(0), FConfiguration.GetText('General', 'Language'));
      RefreshCaptions;
      FToolBar.Visible := True;
      if FConfiguration.GetBoolean('General', 'AlwaysOnTop') then
        FormStyle := fsStayOnTop
      else
        FormStyle := fsNormal;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.RefreshCaptions;
begin
  FileMenu.Caption := FLanguage.Text('File', 'File');
  AddFilesItem.Caption := FLanguage.Text('AddFiles', 'Add files...');
  AddFolderItem.Caption := FLanguage.Text('AddFolder', 'Add folder...');
  OpenItem.Caption := FLanguage.Text('OpenSelected', 'Open selected file');
  OpenFolderItem.Caption := FLanguage.Text('OpenFolder', 'Open containing folder');
  RemoveItem.Caption := FLanguage.Text('RemoveSelected', 'Remove selected');
  ClearItem.Caption := FLanguage.Text('ClearList', 'Clear list');
  ExitItem.Caption := FLanguage.Text('Exit', 'Exit');
  OptimizeMenu.Caption := FLanguage.Text('Optimize', 'Optimize');
  OptimizeItem.Caption := FLanguage.Text('OptimizeAll', 'Optimize all');
  StopItem.Caption := FLanguage.Text('Stop', 'Stop');
  OptionsMenu.Caption := FLanguage.Text('Options', 'Options');
  OptionsItem.Caption := FLanguage.Text('Options', 'Options...');
  HelpMenu.Caption := FLanguage.Text('Help', 'Help');
  InformationItem.Caption := FLanguage.Text('Information', 'Information...');
  AboutItem.Caption := FLanguage.Text('About', 'About...');
  AddFilesButton.Hint := FLanguage.Text('ToolbarAddFile', 'Add File');
  AddFolderButton.Hint := FLanguage.Text('ToolbarAddFolder', 'Add Folder');
  RemoveButton.Hint := FLanguage.Text('ToolbarRemove', 'Remove');
  ClearButton.Hint := FLanguage.Text('ToolbarClear', 'Clear');
  OptimizeButton.Hint := FLanguage.Text('ToolbarOptimize', 'Optimize');
  StopButton.Hint := FLanguage.Text('Stop', 'Stop');
  OptionsButton.Hint := FLanguage.Text('ToolbarOptions', 'Options');
  FGrid.Cells[0, 0] := FLanguage.Text('Name', 'File');
  FGrid.Cells[1, 0] := FLanguage.Text('Extension', 'Extension (type)');
  FGrid.Cells[2, 0] := FLanguage.Text('OriginalSize', 'Original size');
  FGrid.Cells[3, 0] := FLanguage.Text('OptimizedSize', 'Optimized size');
  FGrid.Cells[4, 0] := FLanguage.Text('Status', 'Status');
  ContextOptimizeItem.Caption := OptimizeItem.Caption;
  ContextStopItem.Caption := StopItem.Caption;
  ContextOptionsItem.Caption := OptionsItem.Caption;
  ContextRemoveItem.Caption := RemoveItem.Caption;
  ContextClearItem.Caption := ClearItem.Caption;
  ContextOpenItem.Caption := OpenItem.Caption;
  ContextOpenFolderItem.Caption := OpenFolderItem.Caption;
  ContextAboutItem.Caption := AboutItem.Caption;
  ContextInformationItem.Caption := InformationItem.Caption;
end;

procedure TMainForm.RefreshGrid(Sender: TObject);
var
  Completed, Index, LatestStarted, Percent: Integer;
  HasPathArgument: Boolean;
  Entry: TFileResult;
  SavedBytes, TotalBytes: Int64;
  StatusText, Summary, TitleText: string;
begin
  if FCommandLineMode and not FOptimizing and (FStartupTick > 0) and (GetTickCount64 - FStartupTick >= QWord(Max(0, FConfiguration.GetInteger('General', 'StartupDelay')))) then
  begin
    FStartupTick := 0;
    HasPathArgument := False;
    for Index := 1 to ParamCount do
      if (ParamStr(Index) <> '') and (ParamStr(Index)[1] <> '/') then
      begin
        HasPathArgument := True;
        AddPath(ParamStr(Index));
      end;
    if FService.Count > 0 then
      OptimizeClick(Sender)
    else
    begin
      FCommandLineMode := False;
      if HasPathArgument then
      begin
        MessageDlg(FLanguage.Text('NoSupportedFiles', 'No supported files were found in the command-line paths.'), mtInformation, [mbOK], 0);
        Close;
        Exit;
      end;
    end;
  end;
  FGrid.RowCount := Max(2, FService.Count + 1);
  if FService.Count = 0 then
    FGrid.Rows[1].Clear;
  Completed := 0;
  SavedBytes := 0;
  TotalBytes := 0;
  for Index := 0 to FService.Count - 1 do
  begin
    Entry := FService.Item(Index);
    if FConfiguration.GetInteger('General', 'FilenameFormat') = 1 then
      FGrid.Cells[0, Index + 1] := ExtractFileName(Entry.FileName)
    else
      FGrid.Cells[0, Index + 1] := Entry.FileName;
    FGrid.Cells[1, Index + 1] := ExtractFileExt(Entry.FileName);
    if not SameText(FGrid.Cells[1, Index + 1], Entry.DetectedExtension) then
      FGrid.Cells[1, Index + 1] := FGrid.Cells[1, Index + 1] + ' (' + Entry.DetectedExtension + ')';
    FGrid.Cells[2, Index + 1] := NumberText(Entry.OriginalSize);
    if Entry.State in [fsRunning, fsDone, fsFailed] then
      FGrid.Cells[3, Index + 1] := NumberText(Entry.OptimizedSize)
    else
      FGrid.Cells[3, Index + 1] := '';
    case Entry.State of
      fsPending: StatusText := FLanguage.Text('Pending', 'Pending');
      fsRunning: StatusText := FLanguage.Text('Running', 'Running');
      fsDone:
      begin
        StatusText := FLanguage.Text('Done', 'Done');
        if Entry.OriginalSize > 0 then
          StatusText := StatusText + Format(' (%3d%%) ', [Trunc(Entry.OptimizedSize / Entry.OriginalSize * 100)]) + FLanguage.Text('In', 'in') + ' ' + ElapsedText(Entry.ElapsedMilliseconds);
      end;
      fsSkipped: StatusText := FLanguage.Text('Skipped', 'Skipped');
      fsFailed: StatusText := FLanguage.Text('Failed', 'Failed');
      fsCancelled: StatusText := FLanguage.Text('Cancelled', 'Cancelled');
      fsCached: StatusText := FLanguage.Text('Optimized', 'Optimized');
    end;
    if (Entry.State = fsRunning) and (Entry.Detail <> '') then
      StatusText := StatusText + ' ' + Entry.Detail + '...'
    else if Entry.Detail = 'No compatible plugin programs were run' then
      StatusText := StatusText + ': ' + FLanguage.Text('NoCompatiblePlugins', Entry.Detail)
    else if Entry.Detail = 'No smaller result' then
      StatusText := StatusText + ': ' + FLanguage.Text('NoSmallerResult', Entry.Detail)
    else if Entry.Detail <> '' then
      StatusText := StatusText + ': ' + Entry.Detail;
    FGrid.Cells[4, Index + 1] := StatusText;
    if Entry.State in [fsDone, fsSkipped, fsFailed, fsCached] then
      Inc(Completed);
    if Entry.PluginRuns > 0 then
    begin
      Inc(TotalBytes, Entry.OriginalSize);
      if Entry.State = fsDone then
        Inc(SavedBytes, Entry.OriginalSize - Entry.OptimizedSize);
    end;
  end;
  FProgress.Max := Max(1, FService.Count);
  FProgress.Position := Completed;
  if TotalBytes > 0 then
    Percent := Trunc((TotalBytes - SavedBytes) / TotalBytes * 100)
  else
    Percent := 0;
  if Assigned(FTaskbar) then
  begin
    if FService.Count = 0 then
      FTaskbar.SetProgressState(Handle, TBPF_NOPROGRESS)
    else
    begin
      FTaskbar.SetProgressState(Handle, TBPF_NORMAL);
      FTaskbar.SetProgressValue(Handle, Completed, FService.Count);
    end;
  end;
  LatestStarted := FService.LatestStartedIndex;
  if FOptimizing then
  begin
    if LatestStarted >= 0 then
    begin
      FStatus.Caption := Format(FLanguage.Text('Processing', 'Processing %s...'), [FService.Item(LatestStarted).FileName]);
      if FGrid.Row <> LatestStarted + 1 then
        FGrid.Row := LatestStarted + 1;
    end
    else
      FStatus.Caption := NumberText(Completed) + ' / ' + NumberText(FService.Count) + ' ' + FLanguage.Text('Files', 'files');
    TitleText := NumberText(Completed) + ' / ' + NumberText(FService.Count) + ' ' + FLanguage.Text('Files', 'files') + '. ' + NumberText(SavedBytes) + ' ' + FLanguage.Text('BytesSaved', 'bytes saved') + ' (' + NumberText(Percent) + '%)';
  end
  else if FSummary <> '' then
  begin
    FStatus.Caption := FSummary;
    TitleText := FSummary;
  end
  else if FService.Count > 0 then
  begin
    FStatus.Caption := '0 / ' + NumberText(FService.Count) + ' ' + FLanguage.Text('Files', 'files');
    TitleText := FStatus.Caption;
  end
  else
  begin
    FStatus.Caption := '';
    TitleText := '';
  end;
  Caption := 'FileOptimizer';
  if TitleText <> '' then
    Caption := TitleText + ' - FileOptimizer';
  Application.Title := Caption;
  AddFilesButton.Enabled := not FOptimizing;
  AddFolderButton.Enabled := not FOptimizing;
  AddFilesItem.Enabled := not FOptimizing;
  AddFolderItem.Enabled := not FOptimizing;
  ClearButton.Enabled := not FOptimizing and (FService.Count > 0);
  RemoveButton.Enabled := ClearButton.Enabled;
  OpenItem.Enabled := ClearButton.Enabled;
  OpenFolderItem.Enabled := ClearButton.Enabled;
  ContextOpenItem.Enabled := ClearButton.Enabled;
  ContextOpenFolderItem.Enabled := ClearButton.Enabled;
  ClearItem.Enabled := ClearButton.Enabled;
  RemoveItem.Enabled := ClearButton.Enabled;
  ContextClearItem.Enabled := ClearButton.Enabled;
  ContextRemoveItem.Enabled := ClearButton.Enabled;
  OptimizeButton.Enabled := ClearButton.Enabled;
  OptimizeItem.Enabled := ClearButton.Enabled;
  ContextOptimizeItem.Enabled := ClearButton.Enabled;
  ContextStopItem.Enabled := FOptimizing;
  ContextOptionsItem.Enabled := True;
  ContextAboutItem.Enabled := True;
  ContextInformationItem.Enabled := True;
  StopButton.Enabled := FOptimizing;
  StopItem.Enabled := FOptimizing;
  if AllowDropFiles = FOptimizing then
    AllowDropFiles := not FOptimizing;
  if FOptimizing and FService.Finished then
  begin
    Summary := Format(FLanguage.Text('Summary', '%s files processed. %s bytes saved (%s%%). Elapsed time %s'), [NumberText(Completed), NumberText(SavedBytes), NumberText(Percent), ElapsedText(GetTickCount64 - FStartedTick)]);
    FSummary := Summary;
    FStatus.Caption := Summary;
    Caption := Summary + ' - FileOptimizer';
    Application.Title := Caption;
    FOptimizing := False;
    FService.Stop;
    if FConfiguration.GetBoolean('General', 'DisableSleep') then
      SetThreadExecutionState(ES_CONTINUOUS);
    if FConfiguration.GetBoolean('General', 'BeepWhenDone') and not FCommandLineMode then
    begin
      MessageBeep($FFFFFFFF);
      FlashWindow(Handle, False);
      MessageDlg(Summary, mtInformation, [mbOK], 0);
    end;
    if FConfiguration.GetBoolean('General', 'ShutdownWhenDone') then
      if not ShutdownWindows then
        MessageDlg(FLanguage.Text('ShutdownFailed', 'Unable to shut down Windows.'), mtError, [mbOK], 0);
    if FConfiguration.GetBoolean('General', 'ClearWhenComplete') then
    begin
      FService.Clear;
      FSummary := '';
    end;
    if FCommandLineMode then
      Close;
  end;
end;

procedure TMainForm.RemoveClick(Sender: TObject);
var
  Index: Integer;
begin
  if not FOptimizing then
  begin
    for Index := FGrid.Selection.Bottom downto FGrid.Selection.Top do
      if Index > 0 then
        FService.RemoveItem(Index - 1);
    FSummary := '';
  end;
end;

procedure TMainForm.ClearClick(Sender: TObject);
begin
  if not FOptimizing then
  begin
    FService.Clear;
    FSummary := '';
  end;
end;

procedure TMainForm.StopClick(Sender: TObject);
begin
  if FOptimizing then
    FService.Stop;
end;

procedure TMainForm.SaveWindow;
var
  Index: Integer;
  Saved: TMemIniFile;
begin
  if WindowState = wsNormal then
  begin
    FConfiguration.SetInteger('Window', 'Left', Left);
    FConfiguration.SetInteger('Window', 'Top', Top);
    FConfiguration.SetInteger('Window', 'Width', Width);
    FConfiguration.SetInteger('Window', 'Height', Height);
  end;
  if WindowState = wsMaximized then
  begin
    FConfiguration.SetInteger('Window', 'Left', RestoredLeft);
    FConfiguration.SetInteger('Window', 'Top', RestoredTop);
    FConfiguration.SetInteger('Window', 'Width', RestoredWidth);
    FConfiguration.SetInteger('Window', 'Height', RestoredHeight);
  end;
  FConfiguration.SetBoolean('Window', 'Maximized', WindowState = wsMaximized);
  FConfiguration.Save;
  Saved := TMemIniFile.Create(FConfiguration.Path);
  try
    Saved.EraseSection('Grid');
    if FConfiguration.GetBoolean('General', 'PersistentGrid') then
    begin
      Saved.WriteInteger('Grid', 'Count', FService.Count);
      for Index := 0 to FService.Count - 1 do
        Saved.WriteString('Grid', 'File' + IntToStr(Index + 1), FService.Item(Index).FileName);
    end;
    Saved.UpdateFile;
  finally
    Saved.Free;
  end;
end;

end.
