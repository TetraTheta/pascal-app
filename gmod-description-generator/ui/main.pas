unit main;

{$mode objfpc}{$H+}

interface

uses
  Buttons, Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls,
  Menus;

type
  TMainForm = class(TForm)
    ButtonCopy: TButton;
    ButtonGenerate: TButton;
    ButtonReset: TButton;
    CheckBoxCSS: TCheckBox;
    CheckBoxHL2: TCheckBox;
    CheckBoxL4D2: TCheckBox;
    CheckBoxNoRD: TCheckBox;
    CheckBoxRecompiled: TCheckBox;
    CheckBoxSCTools: TCheckBox;
    CheckBoxSubtitle: TCheckBox;
    CheckBoxTF2: TCheckBox;
    ComboBoxRDDate: TComboBox;
    ComboBoxRDMonth: TComboBox;
    ComboBoxRDYear: TComboBox;
    FilePopupMenu: TPopupMenu;
    GroupBoxOption: TGroupBox;
    GroupBoxPreview: TGroupBox;
    LabelAuthor: TLabel;
    LabelDescription: TLabel;
    LabelMapList: TLabel;
    LabelRecommendation: TLabel;
    LabelReleaseDate: TLabel;
    LabelRequirements: TLabel;
    LabelSynopsis: TLabel;
    LabelTitle: TLabel;
    LabelWarning: TLabel;
    MenuFileButton: TSpeedButton;
    MenuItemExit: TMenuItem;
    MenuItemOpen: TMenuItem;
    MenuItemSave: TMenuItem;
    MenuItemSeparator: TMenuItem;
    MenuStripPanel: TPanel;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    TextBoxAuthor: TEdit;
    TextBoxDescription: TMemo;
    TextBoxMapList: TMemo;
    TextBoxPreview: TMemo;
    TextBoxSynopsis: TMemo;
    TextBoxTitle: TEdit;
    TextBoxWarning: TMemo;
    procedure ButtonCopyClick(Sender: TObject);
    procedure ButtonGenerateClick(Sender: TObject);
    procedure ButtonResetClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MenuFileButtonClick(Sender: TObject);
    procedure MenuItemExitClick(Sender: TObject);
    procedure MenuItemOpenClick(Sender: TObject);
    procedure MenuItemSaveClick(Sender: TObject);
  private
    FToday: TDateTime;
    procedure ApplyDefaultDate;
    function BuildSettingsJson: string;
    function ComboText(AComboBox: TComboBox): string;
    function GetJsonBool(AObject: TObject; const AName: string; ADefault: Boolean): Boolean;
    function GetJsonInt(AObject: TObject; const AName: string; ADefault: Integer): Integer;
    function GetJsonString(AObject: TObject; const AName: string): string;
    function LoadTextFile(const AFilePath: string): string;
    function MemoTrimmedLines(AMemo: TMemo): TStringList;
    function NativeLine(const AText: string): string;
    procedure OpenFile(const AFilePath: string);
    procedure RegisterDragDrop(AControl: TControl);
    procedure ResetFields;
    procedure SetDialogDirectory(const AFilePath: string);
    procedure SetSelectedIndex(AComboBox: TComboBox; AIndex: Integer);
    procedure SaveTextFile(const AFilePath: string; const AText: string);
    function TrimmedText(AControl: TControl): string;
    function UnixLine(const AText: string): string;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  Clipbrd, fpjson, jsonparser, LCLType
  {$IFDEF MSWINDOWS}, Windows, ShlObj{$ENDIF};

const
  JsonFilterAll = 'JSON 파일 (*.json)|*.json|모든 파일 (*.*)|*.*';
  JsonFilterOnly = 'JSON 파일 (*.json)|*.json';
  MonthNames: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );

function GetDocumentsDir: string;
{$IFDEF MSWINDOWS}
var
  Path: array[0..MAX_PATH] of WideChar;
begin
  if Succeeded(SHGetFolderPathW(0, CSIDL_PERSONAL, 0, 0, @Path[0])) then
    Result := IncludeTrailingPathDelimiter(UTF8Encode(WideCharToString(Path)))
  else
    Result := GetUserDir;
end;
{$ELSE}
begin
  Result := GetUserDir;
end;
{$ENDIF}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FToday := Date;
  ApplyDefaultDate;

  OpenDialog.InitialDir := GetDocumentsDir;
  SaveDialog.InitialDir := OpenDialog.InitialDir;
  OpenDialog.Filter := JsonFilterAll;
  SaveDialog.Filter := JsonFilterOnly;
  SaveDialog.DefaultExt := 'json';

  MenuItemOpen.ShortCut := ShortCut(VK_O, [ssCtrl]);
  MenuItemSave.ShortCut := ShortCut(VK_S, [ssCtrl]);

  RegisterDragDrop(Self);
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Shift <> [ssCtrl] then
    Exit;

  case Key of
    VK_O:
      begin
        MenuItemOpenClick(Sender);
        Key := 0;
      end;
    VK_S:
      begin
        MenuItemSaveClick(Sender);
        Key := 0;
      end;
  end;
end;

procedure TMainForm.MenuFileButtonClick(Sender: TObject);
var
  PopupPoint: TPoint;
begin
  PopupPoint.X := 0;
  PopupPoint.Y := MenuFileButton.Height;
  PopupPoint := MenuFileButton.ClientToScreen(PopupPoint);
  FilePopupMenu.PopUp(PopupPoint.X, PopupPoint.Y);
end;

procedure TMainForm.ButtonResetClick(Sender: TObject);
begin
  if MessageDlg('Important Question', 'Are you sure want to reset?', mtConfirmation,
    [mbYes, mbNo], 0) = mrYes then
    ResetFields;
end;

procedure TMainForm.ButtonCopyClick(Sender: TObject);
var
  Preview: string;
begin
  Preview := NativeLine(Trim(TextBoxPreview.Text));
  if Preview = '' then
    Exit;

  Clipboard.AsText := Preview;
  MessageDlg('Copied', 'Copied Preview text.', mtInformation, [mbOK], 0);
end;

procedure TMainForm.ButtonGenerateClick(Sender: TObject);
var
  Css: Boolean;
  Hl2: Boolean;
  L4d2: Boolean;
  Lines: TStringList;
  Recompiled: Boolean;
  Builder: TStringBuilder;
  Tf2: Boolean;
  Warning: string;
  I: Integer;
begin
  Builder := TStringBuilder.Create;
  Lines := nil;
  try
    Builder.Append(Format('[h1]%s[/h1]'#10, [TrimmedText(TextBoxTitle)]));
    Builder.Append(Format('[i]created by %s[/i]'#10, [TrimmedText(TextBoxAuthor)]));

    if not CheckBoxNoRD.Checked then
      Builder.Append(Format(#10'Date of publish: %s %s %s'#10,
        [ComboText(ComboBoxRDDate), ComboText(ComboBoxRDMonth), ComboText(ComboBoxRDYear)]));

    Builder.Append('[hr][/hr]');

    if TrimmedText(TextBoxDescription) <> '' then
      Builder.Append(Format('[h2]Description[/h2]'#10'%s'#10, [TrimmedText(TextBoxDescription)]));

    if TrimmedText(TextBoxSynopsis) <> '' then
      Builder.Append(Format('[h2]Synopsis[/h2]'#10'%s'#10, [TrimmedText(TextBoxSynopsis)]));

    Hl2 := CheckBoxHL2.Checked;
    Css := CheckBoxCSS.Checked;
    Tf2 := CheckBoxTF2.Checked;
    L4d2 := CheckBoxL4D2.Checked;
    if Hl2 or Css or Tf2 or L4d2 then
    begin
      Builder.Append('[h2]Requirements[/h2]'#10'[list]'#10);
      if Hl2 then
        Builder.Append('  [*]Half-Life 2 (+ Episode One, Episode Two)'#10);
      if Css then
        Builder.Append('  [*]Counter-Strike: Source'#10);
      if Tf2 then
        Builder.Append('  [*]Team Fortress 2'#10);
      if L4d2 then
        Builder.Append('  [*]Left 4 Dead 2'#10);
      Builder.Append('[/list]'#10);
      Builder.Append('[u]Mount them anyway; Garry''s Mod''s default assets lack [b]music and voice-overs[/b].[/u]'#10);
    end;

    Lines := MemoTrimmedLines(TextBoxMapList);
    if Lines.Count > 0 then
    begin
      Builder.Append('[h2]Map List[/h2]'#10'[list]'#10);
      for I := 0 to Lines.Count - 1 do
        Builder.Append(Format('  [*]%s'#10, [Lines[I]]));
      Builder.Append('[/list]'#10);
    end;

    Builder.Append('[h2]Recommendations[/h2]'#10);
    Builder.Append('To prevent or troubleshoot CTDs, frame drops, and add-on issues:'#10);
    Builder.Append('[olist]'#10);
    Builder.Append('  [*]Use 64-bit GMod via the ''x86-64'' beta branch.'#10);
    Builder.Append('  [*]Disable or unsubscribe from unnecessary add-ons.'#10);
    Builder.Append('  [*][Troubleshooting] Unsubscribe from all other add-ons (keep only this one).'#10);
    Builder.Append('  [*][Troubleshooting] Factory reset GMod using ''FactoryReset-GMod.bat''.'#10);
    Builder.Append('[/olist]'#10);
    Builder.Append('The maps tested fine without lags or CTDs. Any issues you encounter are likely system-specific, which unfortunately I can''t fix.'#10);
    if CheckBoxSCTools.Checked then
      Builder.Append(#10'[url=https://steamcommunity.com/sharedfiles/filedetails/?id=3207465120]SC Tools[/url] is required for level transitions and custom entities. You can still play without it, but many things won''t work.'#10)
    else
      Builder.Append(#10'I highly recommend subscribing to [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3207465120]SC Tools[/url] for a [i]better[/i] experience.'#10);

    if CheckBoxSubtitle.Checked then
      Builder.Append(#10'Subscribe to [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3311765429]Simplest Subtitles Framework[/url] for closed captions (highly recommended).'#10);

    Recompiled := CheckBoxRecompiled.Checked;
    Warning := TrimmedText(TextBoxWarning);
    if Recompiled or (Warning <> '') then
    begin
      Builder.Append('[h2]Warning[/h2]'#10);
      if Recompiled then
      begin
        Builder.Append('This add-on includes recompiled maps for fixes and optimization.'#10);
        Builder.Append('Please report any [b]new[/b] glitches or issues; I will try to fix them.'#10);
      end;
      if Warning <> '' then
      begin
        if Recompiled then
          Builder.Append(#10);
        Builder.Append(Warning).Append(#10);
      end;
    end;

    Builder.Append('[h2]Disclaimer[/h2]'#10);
    Builder.Append('Tested only in Singleplayer Sandbox on the ''x86-64'' beta branch. Compatibility with other gamemodes or Multiplayer is not guaranteed.'#10#10);
    Builder.Append('I did not create these maps; I only [i]ported[/i] them to Garry''s Mod. All credit goes to the original authors.'#10);
    Builder.Append('[hr][/hr]Search Tag: [spoiler]half life hl2 custom campaign[/spoiler]');

    TextBoxPreview.Text := NativeLine(Builder.ToString);
  finally
    Lines.Free;
    Builder.Free;
  end;
end;

procedure TMainForm.MenuItemOpenClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    OpenFile(OpenDialog.FileName);
end;

procedure TMainForm.MenuItemSaveClick(Sender: TObject);
begin
  if not SaveDialog.Execute then
    Exit;

  try
    SaveTextFile(SaveDialog.FileName, BuildSettingsJson);
    SetDialogDirectory(SaveDialog.FileName);
    MessageDlg('SAVE SUCCESSFUL', 'Save complete', mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('ERROR', Format('Error occurred while saving file: %s', [E.Message]),
        mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.MenuItemExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainForm.FormDropFiles(Sender: TObject; const FileNames: array of string);
begin
  if (Length(FileNames) = 1) and SameText(ExtractFileExt(FileNames[0]), '.json') then
    OpenFile(FileNames[0]);
end;

procedure TMainForm.ApplyDefaultDate;
var
  Day: Word;
  Month: Word;
  Year: Word;
begin
  DecodeDate(FToday, Year, Month, Day);
  ComboBoxRDDate.ItemIndex := ComboBoxRDDate.Items.IndexOf(IntToStr(Day));
  ComboBoxRDMonth.ItemIndex := ComboBoxRDMonth.Items.IndexOf(MonthNames[Month]);
  ComboBoxRDYear.ItemIndex := ComboBoxRDYear.Items.IndexOf(IntToStr(Year));
end;

function TMainForm.BuildSettingsJson: string;
var
  Json: TJSONObject;
begin
  Json := TJSONObject.Create;
  try
    Json.Add('Title', UnixLine(TrimmedText(TextBoxTitle)));
    Json.Add('Author', UnixLine(TrimmedText(TextBoxAuthor)));
    Json.Add('RDDate', ComboBoxRDDate.ItemIndex);
    Json.Add('RDMonth', ComboBoxRDMonth.ItemIndex);
    Json.Add('RDYear', ComboBoxRDYear.ItemIndex);
    Json.Add('NoRD', CheckBoxNoRD.Checked);
    Json.Add('Description', UnixLine(TrimmedText(TextBoxDescription)));
    Json.Add('Synopsis', UnixLine(TrimmedText(TextBoxSynopsis)));
    Json.Add('HL2', CheckBoxHL2.Checked);
    Json.Add('CSS', CheckBoxCSS.Checked);
    Json.Add('TF2', CheckBoxTF2.Checked);
    Json.Add('L4D2', CheckBoxL4D2.Checked);
    Json.Add('MapList', UnixLine(TrimmedText(TextBoxMapList)));
    Json.Add('Subtitle', CheckBoxSubtitle.Checked);
    Json.Add('SCTools', CheckBoxSCTools.Checked);
    Json.Add('Recompiled', CheckBoxRecompiled.Checked);
    Json.Add('Warning', UnixLine(TrimmedText(TextBoxWarning)));
    Result := Json.AsJSON;
  finally
    Json.Free;
  end;
end;

function TMainForm.ComboText(AComboBox: TComboBox): string;
begin
  Result := Trim(AComboBox.Text);
end;

function TMainForm.GetJsonBool(AObject: TObject; const AName: string; ADefault: Boolean): Boolean;
begin
  Result := TJSONObject(AObject).Get(AName, ADefault);
end;

function TMainForm.GetJsonInt(AObject: TObject; const AName: string; ADefault: Integer): Integer;
begin
  Result := TJSONObject(AObject).Get(AName, ADefault);
end;

function TMainForm.GetJsonString(AObject: TObject; const AName: string): string;
begin
  Result := Trim(TJSONObject(AObject).Get(AName, ''));
end;

function TMainForm.LoadTextFile(const AFilePath: string): string;
var
  Stream: TFileStream;
begin
  Result := '';
  Stream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Stream.Size);
    if Result <> '' then
      Stream.ReadBuffer(Pointer(Result)^, Length(Result));
  finally
    Stream.Free;
  end;
end;

function TMainForm.MemoTrimmedLines(AMemo: TMemo): TStringList;
var
  I: Integer;
  Line: string;
begin
  Result := TStringList.Create;
  for I := 0 to AMemo.Lines.Count - 1 do
  begin
    Line := Trim(AMemo.Lines[I]);
    if Line <> '' then
      Result.Add(Line);
  end;
end;

function TMainForm.NativeLine(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #10, LineEnding, [rfReplaceAll]);
end;

procedure TMainForm.OpenFile(const AFilePath: string);
var
  Data: TJSONData;
  Json: TJSONObject;
begin
  Data := nil;
  try
    Data := GetJSON(LoadTextFile(AFilePath));
    if not (Data is TJSONObject) then
      raise EReadError.Create('Could not parse JSON file content');

    Json := TJSONObject(Data);
    TextBoxTitle.Text := NativeLine(GetJsonString(Json, 'Title'));
    TextBoxAuthor.Text := NativeLine(GetJsonString(Json, 'Author'));
    SetSelectedIndex(ComboBoxRDDate, GetJsonInt(Json, 'RDDate', 0));
    SetSelectedIndex(ComboBoxRDMonth, GetJsonInt(Json, 'RDMonth', 0));
    SetSelectedIndex(ComboBoxRDYear, GetJsonInt(Json, 'RDYear', 0));
    CheckBoxNoRD.Checked := GetJsonBool(Json, 'NoRD', False);
    TextBoxDescription.Text := NativeLine(GetJsonString(Json, 'Description'));
    TextBoxSynopsis.Text := NativeLine(GetJsonString(Json, 'Synopsis'));
    CheckBoxHL2.Checked := GetJsonBool(Json, 'HL2', True);
    CheckBoxCSS.Checked := GetJsonBool(Json, 'CSS', False);
    CheckBoxTF2.Checked := GetJsonBool(Json, 'TF2', False);
    CheckBoxL4D2.Checked := GetJsonBool(Json, 'L4D2', False);
    TextBoxMapList.Text := NativeLine(GetJsonString(Json, 'MapList'));
    CheckBoxSubtitle.Checked := GetJsonBool(Json, 'Subtitle', False);
    CheckBoxSCTools.Checked := GetJsonBool(Json, 'SCTools', False);
    CheckBoxRecompiled.Checked := GetJsonBool(Json, 'Recompiled', False);
    TextBoxWarning.Text := NativeLine(GetJsonString(Json, 'Warning'));

    SaveDialog.FileName := AFilePath;
    SetDialogDirectory(AFilePath);
  except
    on E: Exception do
      MessageDlg('ERROR', Format('Error occurred while opening file: %s', [E.Message]),
        mtError, [mbOK], 0);
  end;
  Data.Free;
end;

procedure TMainForm.RegisterDragDrop(AControl: TControl);
var
  ChildIndex: Integer;
begin
  if AControl is TCustomForm then
  begin
    TCustomForm(AControl).AllowDropFiles := True;
    TCustomForm(AControl).OnDropFiles := @FormDropFiles;
  end;

  if AControl is TWinControl then
    for ChildIndex := 0 to TWinControl(AControl).ControlCount - 1 do
      RegisterDragDrop(TWinControl(AControl).Controls[ChildIndex]);
end;

procedure TMainForm.ResetFields;
begin
  TextBoxTitle.Clear;
  TextBoxAuthor.Clear;
  ApplyDefaultDate;
  CheckBoxNoRD.Checked := False;
  TextBoxDescription.Clear;
  TextBoxSynopsis.Clear;
  CheckBoxHL2.Checked := True;
  CheckBoxCSS.Checked := False;
  CheckBoxTF2.Checked := False;
  CheckBoxL4D2.Checked := False;
  TextBoxMapList.Clear;
  CheckBoxSubtitle.Checked := False;
  CheckBoxSCTools.Checked := False;
  CheckBoxRecompiled.Checked := False;
  TextBoxWarning.Clear;
  TextBoxPreview.Clear;
end;

procedure TMainForm.SetDialogDirectory(const AFilePath: string);
var
  Directory: string;
begin
  Directory := ExtractFileDir(AFilePath);
  if Directory = '' then
    Exit;

  OpenDialog.InitialDir := Directory;
  SaveDialog.InitialDir := Directory;
end;

procedure TMainForm.SetSelectedIndex(AComboBox: TComboBox; AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < AComboBox.Items.Count) then
    AComboBox.ItemIndex := AIndex
  else
    AComboBox.ItemIndex := 0;
end;

procedure TMainForm.SaveTextFile(const AFilePath: string; const AText: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFilePath, fmCreate);
  try
    if AText <> '' then
      Stream.WriteBuffer(Pointer(AText)^, Length(AText));
  finally
    Stream.Free;
  end;
end;

function TMainForm.TrimmedText(AControl: TControl): string;
begin
  if AControl is TCustomEdit then
    Result := Trim(TCustomEdit(AControl).Text)
  else
    Result := Trim(AControl.Caption);
end;

function TMainForm.UnixLine(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

end.
