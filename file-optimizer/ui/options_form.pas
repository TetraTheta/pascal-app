unit options_form;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  Forms,
  Controls,
  StdCtrls,
  ComCtrls,
  ExtCtrls,
  Spin,
  optimizer_configuration,
  language_service;

type
  TOptionsForm = class(TForm)
    BottomPanel: TPanel;
    CancelButton: TButton;
    RestoreButton: TButton;
    SaveButton: TButton;
    FPages: TPageControl;
    Label0: TLabel;
    Label1: TLabel;
    Label3: TLabel;
    Label10: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label19: TLabel;
    Label20: TLabel;
    Label22: TLabel;
    Label23: TLabel;
    Label26: TLabel;
    Label27: TLabel;
    Label30: TLabel;
    Label40: TLabel;
    Label48: TLabel;
    Label49: TLabel;
    Option0: TComboBox;
    Option1: TComboBox;
    Option2: TCheckBox;
    Option3: TSpinEdit;
    Option4: TCheckBox;
    Option5: TCheckBox;
    Option6: TCheckBox;
    Option7: TCheckBox;
    Option8: TCheckBox;
    Option9: TCheckBox;
    Option10: TEdit;
    Option11: TCheckBox;
    Option12: TCheckBox;
    Option13: TCheckBox;
    Option14: TCheckBox;
    Option15: TEdit;
    Option16: TComboBox;
    Option17: TEdit;
    Option18: TCheckBox;
    Option19: TSpinEdit;
    Option20: TComboBox;
    Option21: TCheckBox;
    Option22: TSpinEdit;
    Option23: TComboBox;
    Option25: TCheckBox;
    Option26: TSpinEdit;
    Option27: TEdit;
    Option28: TCheckBox;
    Option29: TCheckBox;
    Option30: TComboBox;
    Option31: TCheckBox;
    Option32: TCheckBox;
    Option33: TCheckBox;
    Option34: TCheckBox;
    Option35: TCheckBox;
    Option36: TCheckBox;
    Option37: TCheckBox;
    Option38: TCheckBox;
    Option39: TCheckBox;
    Option40: TEdit;
    Option41: TCheckBox;
    Option42: TCheckBox;
    Option43: TCheckBox;
    Option44: TCheckBox;
    Option45: TCheckBox;
    Option46: TCheckBox;
    Option47: TCheckBox;
    Option48: TSpinEdit;
    Option49: TComboBox;
    Option50: TCheckBox;
    Option51: TCheckBox;
    Option52: TCheckBox;
    Option53: TCheckBox;
    Option54: TCheckBox;
    Option55: TCheckBox;
    Option56: TCheckBox;
    Option57: TCheckBox;
    Option58: TCheckBox;
    Option59: TCheckBox;
    Option60: TCheckBox;
    PageBMP: TTabSheet;
    PageCSS: TTabSheet;
    PageEXE: TTabSheet;
    PageGeneral: TTabSheet;
    PageGIF: TTabSheet;
    PageGZ: TTabSheet;
    PageHTML: TTabSheet;
    PageJPEG: TTabSheet;
    PageJS: TTabSheet;
    PageLUA: TTabSheet;
    PageMisc: TTabSheet;
    PageMP3: TTabSheet;
    PageMP4: TTabSheet;
    PagePCX: TTabSheet;
    PagePDF: TTabSheet;
    PagePNG: TTabSheet;
    PageTGA: TTabSheet;
    PageTIFF: TTabSheet;
    PageWAV: TTabSheet;
    PageWEBP: TTabSheet;
    PageXML: TTabSheet;
    PageZIP: TTabSheet;
    ScrollBMP: TScrollBox;
    ScrollCSS: TScrollBox;
    ScrollEXE: TScrollBox;
    ScrollGeneral: TScrollBox;
    ScrollGIF: TScrollBox;
    ScrollGZ: TScrollBox;
    ScrollHTML: TScrollBox;
    ScrollJPEG: TScrollBox;
    ScrollJS: TScrollBox;
    ScrollLUA: TScrollBox;
    ScrollMisc: TScrollBox;
    ScrollMP3: TScrollBox;
    ScrollMP4: TScrollBox;
    ScrollPCX: TScrollBox;
    ScrollPDF: TScrollBox;
    ScrollPNG: TScrollBox;
    ScrollTGA: TScrollBox;
    ScrollTIFF: TScrollBox;
    ScrollWAV: TScrollBox;
    ScrollWEBP: TScrollBox;
    ScrollXML: TScrollBox;
    ScrollZIP: TScrollBox;
  private
    FConfiguration: TOptimizerConfiguration;
    FLanguage: TLanguageService;
    FControls: array of TControl;
    FReadOnly: Boolean;
    procedure BuildCategoryPages;
    procedure LoadControls;
  published
    procedure SaveClick(Sender: TObject);
    procedure RestoreClick(Sender: TObject);
  public
    constructor CreateOptions(AOwner: TComponent; AConfiguration: TOptimizerConfiguration; ALanguage: TLanguageService; AReadOnly: Boolean = False);
  end;

implementation

{$R *.lfm}

uses
  SysUtils,
  Dialogs,
  Math,
  StrUtils;

function ReadableName(const AName: string): string;
var
  Index: Integer;
begin
  Result := '';
  for Index := 1 to Length(AName) do begin
    if (Index > 1) and (AName[Index] in ['A'..'Z']) and (AName[Index - 1] in ['a'..'z', '0'..'9']) then
      Result := Result + ' ';
    Result := Result + AName[Index];
  end;
end;

function OptionHint(const AName: string): string;
begin
  case AName of
    'AdditionalExtensions': Result := 'Comma-separated extensions to process as JS or JSON.';
    'AllowDuplicates': Result := 'Allow adding the same file more than once.';
    'AllowLossy': Result := 'Allow smaller files at the cost of possible quality loss.';
    'AllowMultipleInstances': Result := 'Allow more than one FileOptimizer window.';
    'AlwaysOnTop': Result := 'Keep the main window above other windows.';
    'BeepWhenDone': Result := 'Play a sound when optimization completes.';
    'ClearWhenComplete': Result := 'Clear the file list when optimization completes.';
    'CopyMetadata': Result := 'Keep file metadata that would otherwise be removed.';
    'CustomDPI': Result := 'Set image resolution when the custom PDF profile is selected.';
    'Debug': Result := 'Keep temporary working files for troubleshooting.';
    'Disable': Result := 'Skip processing other file types.';
    'DisablePETrim': Result := 'Skip PETrim for better EXE compatibility at the cost of size.';
    'DisablePluginMask':
      Result := 'Case-insensitive substrings of plugin command lines, separated by commas. Example: oxipng.exe,pingo.exe. No regex or wildcards.';
    'DisableSleep': Result := 'Prevent the computer from sleeping during optimization.';
    'DoNotCreateBackups': Result := 'Do not create .BAK copies beside original files.';
    'DoNotUseRecycleBin': Result := 'Do not copy original files to the Recycle Bin.';
    'EnableCache': Result := 'Skip files already optimized according to the cache.';
    'EnableJSMin': Result := 'Run JSMin for smaller files; the result may be harder to edit.';
    'EnableLeanify': Result := 'Run Leanify for smaller files; the result may be harder to edit.';
    'EnableTidy': Result := 'Run Tidy for smaller files; the result may be harder to edit.';
    'EnableUPX': Result := 'Compress executables with UPX; they decompress when run.';
    'ExcludeMask':
      Result := 'Skip paths containing any comma-separated substring (case-insensitive). Example: \\cache\\,.tmp. No regex or wildcards.';
    'FilenameFormat': Result := 'Choose how file names appear in the list. Partial-path formats currently display the full path.';
    'IncludeMask':
      Result := 'Process only paths containing a comma-separated substring (case-insensitive). Example: .png,images. No regex or wildcards.';
    'KeepAttributes': Result := 'Preserve original file attributes and timestamps.';
    'Language': Result := 'Choose the interface language.';
    'LeanifyIterations': Result := 'Override the number of Leanify trial iterations; -1 uses the optimization level.';
    'Level': Result := 'Optimization level from best speed to best compression.';
    'LogLevel':
      Result := '0-3 do not write plugin entries; 4 writes commands and exit codes to FileOptimizer.log beside the executable. No log window.';
    'ParallelCount': Result := 'Maximum number of files processed at once.';
    'ParallelEnabled': Result := 'Process multiple files at the same time.';
    'PersistentGrid': Result := 'Keep the file list for the next launch.';
    'PNGWolfIterations': Result := 'Override PNGWolf iterations; -1 uses the optimization level.';
    'ProcessPriority': Result := 'Process priority from most conservative to best performance.';
    'Profile': Result := 'Choose PDF compression from smaller size to better quality.';
    'Recurse': Result := 'Optimize files inside archives recursively.';
    'ShutdownWhenDone': Result := 'Shut down the computer when optimization completes.';
    'SkipLayered': Result := 'Skip PDFs with layered objects for better compatibility.';
    'StartupDelay': Result := 'Delay before processing command-line files, in milliseconds.';
    'StripSilence': Result := 'Remove silence from the start and end of WAV audio.';
    'TempDirectory': Result := 'Use this folder for temporary files instead of the system temp folder.';
    'Template': Result := 'Compression template from safer to stronger compression.';
    'UseArithmeticEncoding': Result := 'Use arithmetic encoding; some programs cannot read the result.';
  else
    Result := '';
  end;
end;

function CategoryIndex(const ASection: string): Integer;
begin
  if (ASection = 'BMP')
      or (ASection = 'GIF')
      or (ASection = 'JPEG')
      or (ASection = 'PCX')
      or (ASection = 'PNG')
      or (ASection = 'TGA')
      or (ASection = 'TIFF')
      or (ASection = 'WEBP') then
    Result := 0
  else if (ASection = 'CSS') or (ASection = 'HTML') or (ASection = 'JS') or (ASection = 'LUA') or (ASection = 'PDF') or (ASection = 'XML') then
    Result := 1
  else if (ASection = 'MP3') or (ASection = 'MP4') or (ASection = 'WAV') then
    Result := 2
  else if (ASection = 'GZ') or (ASection = 'ZIP') then
    Result := 3
  else
    Result := 4;
end;

constructor TOptionsForm.CreateOptions(AOwner: TComponent; AConfiguration: TOptimizerConfiguration; ALanguage: TLanguageService; AReadOnly: Boolean);
var
  Index: Integer;
  WorkArea: TRect;
begin
  inherited Create(AOwner);
  FConfiguration := AConfiguration;
  FLanguage := ALanguage;
  FReadOnly := AReadOnly;
  if FReadOnly then
    Caption := FLanguage.Text('OptionsReadOnly', 'Options (read-only)')
  else
    Caption := FLanguage.Text('Options', 'Options');
  SaveButton.Caption := FLanguage.Text('Save', 'Save');
  if FReadOnly then
    CancelButton.Caption := FLanguage.Text('Close', 'Close')
  else
    CancelButton.Caption := FLanguage.Text('Cancel', 'Cancel');
  RestoreButton.Caption := FLanguage.Text('RestoreDefaults', 'Restore defaults');
  BuildCategoryPages;
  LoadControls;
  if FReadOnly then begin
    for Index := 0 to High(FControls) do
      if Assigned(FControls[Index]) then
        FControls[Index].Enabled := False;
    SaveButton.Enabled := False;
    RestoreButton.Enabled := False;
  end;
  WorkArea := Screen.MonitorFromWindow(TForm(AOwner).Handle).WorkareaRect;
  Position := poDesigned;
  Left := EnsureRange(TForm(AOwner).Left + (TForm(AOwner).Width - Width) div 2, WorkArea.Left, WorkArea.Right - Width);
  Top := EnsureRange(TForm(AOwner).Top + (TForm(AOwner).Height - Height) div 2, WorkArea.Top, WorkArea.Bottom - Height);
end;

procedure TOptionsForm.BuildCategoryPages;
const
  CategoryNames: array[0..4] of string = ('Images', 'Documents', 'Media', 'Archives', 'Other');
var
  CategoryPages: array[0..4] of TTabSheet;
  CategoryScrolls: array[0..4] of TScrollBox;
  CategoryTops: array[0..4] of Integer;
  Category, ControlIndex, Index, SectionHeight: Integer;
  Group: TGroupBox;
  OldScroll: TScrollBox;
  Section: string;
  Spec: TOptionSpec;
  MovedLabel: TLabel;
  MovedSpin: TSpinEdit;
  MovedIndex: Integer;
begin
  ScrollGeneral.VertScrollBar.Tracking := True;
  for Category := 0 to High(CategoryPages) do begin
    CategoryPages[Category] := TTabSheet.Create(Self);
    CategoryPages[Category].PageControl := FPages;
    CategoryPages[Category].Caption := FLanguage.Text(CategoryNames[Category], CategoryNames[Category]);
    CategoryScrolls[Category] := TScrollBox.Create(Self);
    CategoryScrolls[Category].Parent := CategoryPages[Category];
    CategoryScrolls[Category].Align := alClient;
    CategoryScrolls[Category].BorderStyle := bsNone;
    CategoryScrolls[Category].VertScrollBar.Tracking := True;
    CategoryTops[Category] := 8;
  end;
  Section := '';
  for Index := 0 to OptionCount - 1 do begin
    Spec := OptionSpec(Index);
    if (Spec.Section = 'General') or (Spec.Section = 'Window') or (Spec.Section = Section) then
      Continue;
    Section := Spec.Section;
    Category := CategoryIndex(Section);
    OldScroll := TScrollBox(FindComponent('Scroll' + Section));
    SectionHeight := 0;
    for ControlIndex := 0 to OldScroll.ControlCount - 1 do
      if OldScroll.Controls[ControlIndex].Top + OldScroll.Controls[ControlIndex].Height > SectionHeight then
        SectionHeight := OldScroll.Controls[ControlIndex].Top + OldScroll.Controls[ControlIndex].Height;
    Group := TGroupBox.Create(Self);
    Group.Name := 'Group' + Section;
    Group.Parent := CategoryScrolls[Category];
    Group.Left := 8;
    Group.Top := CategoryTops[Category];
    Group.Width := CategoryScrolls[Category].ClientWidth - 24;
    Group.Height := SectionHeight + 28;
    Group.Anchors := [akLeft, akTop, akRight];
    while OldScroll.ControlCount > 0 do
      OldScroll.Controls[0].Parent := Group;
    if Section = 'Misc' then
      MovedIndex := 19
    else if Section = 'PNG' then
      MovedIndex := 22
    else
      MovedIndex := -1;
    if MovedIndex >= 0 then begin
      MovedLabel := TLabel(FindComponent('Label' + IntToStr(MovedIndex)));
      MovedSpin := TSpinEdit(FindComponent('Option' + IntToStr(MovedIndex)));
      MovedLabel.Parent := Group;
      MovedSpin.Parent := Group;
      MovedLabel.Top := SectionHeight + 9;
      MovedSpin.Top := SectionHeight + 4;
      Group.Height := Group.Height + 32;
    end;
    CategoryTops[Category] := Group.Top + Group.Height + 8;
    TTabSheet(FindComponent('Page' + Section)).TabVisible := False;
  end;
end;

procedure TOptionsForm.LoadControls;
var
  Choice: TComboBox;
  ChoiceIndex, Index: Integer;
  LabelControl: TLabel;
  Section: string;
  Spec: TOptionSpec;
  Spin: TSpinEdit;
  HintText: string;
begin
  SetLength(FControls, OptionCount);
  Section := '';
  for Index := 0 to OptionCount - 1 do begin
    Spec := OptionSpec(Index);
    if Spec.Section = 'Window' then
      Continue;
    if Spec.Section <> Section then begin
      Section := Spec.Section;
      if Section = 'General' then
        PageGeneral.Caption := FLanguage.Text(Section, Section)
      else
        TGroupBox(FindComponent('Group' + Section)).Caption := FLanguage.Text(Section, Section);
    end;
    ChoiceIndex := Index;
    if Index >= 24 then
      Inc(ChoiceIndex);
    FControls[Index] := TControl(FindComponent('Option' + IntToStr(ChoiceIndex)));
    HintText := FLanguage.Text('Hint' + Spec.Name, OptionHint(Spec.Name));
    FControls[Index].Hint := HintText;
    FControls[Index].ShowHint := True;
    if Spec.Kind = okBoolean then begin
      TCheckBox(FControls[Index]).Caption := FLanguage.Text(Spec.Name, ReadableName(Spec.Name));
      TCheckBox(FControls[Index]).Checked := FConfiguration.GetBoolean(Spec.Section, Spec.Name);
      Continue;
    end;
    LabelControl := TLabel(FindComponent('Label' + IntToStr(ChoiceIndex)));
    LabelControl.Caption := FLanguage.Text(Spec.Name, ReadableName(Spec.Name));
    LabelControl.Hint := HintText;
    LabelControl.ShowHint := True;
    if FControls[Index] is TComboBox then begin
      Choice := TComboBox(FControls[Index]);
      if Spec.Name = 'ProcessPriority' then begin
        Choice.Items.AddObject(FLanguage.Text('PriorityIdle', 'Idle'), TObject(PtrInt($40)));
        Choice.Items.AddObject(FLanguage.Text('PriorityBelowNormal', 'Below normal'), TObject(PtrInt($4000)));
        Choice.Items.AddObject(FLanguage.Text('PriorityNormal', 'Normal'), TObject(PtrInt($20)));
        Choice.Items.AddObject(FLanguage.Text('PriorityAboveNormal', 'Above normal'), TObject(PtrInt($8000)));
        Choice.Items.AddObject(FLanguage.Text('PriorityHigh', 'High'), TObject(PtrInt($80)));
        Choice.Items.AddObject(FLanguage.Text('PriorityRealtime', 'Realtime'), TObject(PtrInt($100)));
      end
      else if Spec.Name = 'Level' then
        Choice.Items.AddStrings(
            [
                FLanguage.Text('Level0', '0: Fastest'),
                FLanguage.Text('Level1', '1: Faster'),
                FLanguage.Text('Level2', '2: Fast'),
                '3',
                '4',
                FLanguage.Text('Level5', '5: Normal (Default)'),
                '6',
                FLanguage.Text('Level7', '7: Good'),
                FLanguage.Text('Level8', '8: Better'),
                FLanguage.Text('Level9', '9: Best')
            ]
        )
      else if Spec.Name = 'FilenameFormat' then
        Choice.Items.AddStrings(
            [
                FLanguage.Text('FilenameFull', 'Full path and filename (Default)'),
                FLanguage.Text('FilenameOnly', 'Filename only'),
                FLanguage.Text('FilenamePartial', 'Partial path (currently full path)'),
                FLanguage.Text('FilenameAbbreviated', 'Abbreviated path (currently full path)')
            ]
        )
      else if Spec.Name = 'LogLevel' then
        Choice.Items.AddStrings(
            [
                FLanguage.Text('Log0', '0: None (Default)'),
                FLanguage.Text('Log1', '1: Critical'),
                FLanguage.Text('Log2', '2: Error'),
                FLanguage.Text('Log3', '3: Warning'),
                FLanguage.Text('Log4', '4: Information')
            ]
        )
      else if Spec.Name = 'Language' then
        Choice.Items.AddStrings(['Auto', 'English', 'Korean'])
      else if Spec.Name = 'Template' then
        Choice.Items.AddStrings(
            [FLanguage.Text('TemplateLow', 'low'), FLanguage.Text('TemplateHigh', 'high'), FLanguage.Text('TemplateHighest', 'highest')]
        )
      else
        Choice.Items.AddStrings(
            [
                FLanguage.Text('ProfileNone', 'none'),
                FLanguage.Text('ProfileScreen', 'screen'),
                FLanguage.Text('ProfileEbook', 'ebook'),
                FLanguage.Text('ProfilePrinter', 'printer'),
                FLanguage.Text('ProfilePrepress', 'prepress'),
                FLanguage.Text('ProfileCustom', 'custom')
            ]
        );
      Choice.ItemIndex := 0;
      for ChoiceIndex := 0 to Choice.Items.Count - 1 do
        if ((Spec.Name = 'ProcessPriority') and (PtrInt(Choice.Items.Objects[ChoiceIndex]) = FConfiguration.GetInteger(Spec.Section, Spec.Name)))
            or (((Spec.Name = 'Level') or (Spec.Name = 'FilenameFormat') or (Spec.Name = 'LogLevel'))
                and (ChoiceIndex = FConfiguration.GetInteger(Spec.Section, Spec.Name)))
            or ((Spec.Name = 'Language')
                and (ChoiceIndex = IndexStr(LowerCase(FConfiguration.GetText(Spec.Section, Spec.Name)), ['auto', 'en', 'ko'])))
            or ((Spec.Name = 'Template')
                and (ChoiceIndex = IndexStr(LowerCase(FConfiguration.GetText(Spec.Section, Spec.Name)), ['low', 'high', 'highest'])))
            or ((Spec.Name = 'Profile')
                and (ChoiceIndex
                    = IndexStr(
                        LowerCase(FConfiguration.GetText(Spec.Section, Spec.Name)),
                        ['none', 'screen', 'ebook', 'printer', 'prepress', 'custom'])))
            or ((Spec.Name <> 'Language')
                and (Spec.Name <> 'Template')
                and (Spec.Name <> 'Profile')
                and (Spec.Name <> 'ProcessPriority')
                and (Spec.Name <> 'Level')
                and (Spec.Name <> 'FilenameFormat')
                and (Spec.Name <> 'LogLevel')
                and SameText(Choice.Items[ChoiceIndex], FConfiguration.GetText(Spec.Section, Spec.Name))) then
          Choice.ItemIndex := ChoiceIndex;
    end
    else if FControls[Index] is TSpinEdit then begin
      Spin := TSpinEdit(FControls[Index]);
      Spin.Value := FConfiguration.GetInteger(Spec.Section, Spec.Name);
    end
    else
      TEdit(FControls[Index]).Text := FConfiguration.GetText(Spec.Section, Spec.Name);
  end;
end;

procedure TOptionsForm.SaveClick(Sender: TObject);
var
  Index: Integer;
  Spec: TOptionSpec;
begin
  if FReadOnly then
    Exit;
  if TCheckBox(FindComponent('Option2')).Checked and TCheckBox(FindComponent('Option4')).Checked then begin
    MessageDlg(
        FLanguage.Text('ParallelDuplicatesWarning', 'Parallel processing cannot be enabled while duplicate files are allowed.'),
        mtWarning,
        [mbOK],
        0
    );
    Exit;
  end;
  for Index := 0 to High(FControls) do begin
    if FControls[Index] = nil then
      Continue;
    Spec := OptionSpec(Index);
    if FControls[Index] is TComboBox then begin
      if Spec.Name = 'ProcessPriority' then
        FConfiguration.SetInteger(Spec.Section, Spec.Name, PtrInt(TComboBox(FControls[Index]).Items.Objects[TComboBox(FControls[Index]).ItemIndex]))
      else if (Spec.Name = 'Level') or (Spec.Name = 'FilenameFormat') or (Spec.Name = 'LogLevel') then
        FConfiguration.SetInteger(Spec.Section, Spec.Name, TComboBox(FControls[Index]).ItemIndex)
      else if Spec.Name = 'Language' then begin
        case TComboBox(FControls[Index]).ItemIndex of
          1: FConfiguration.SetText(Spec.Section, Spec.Name, 'en');
          2: FConfiguration.SetText(Spec.Section, Spec.Name, 'ko');
        else
          FConfiguration.SetText(Spec.Section, Spec.Name, 'auto');
        end;
      end
      else if Spec.Name = 'Template' then begin
        case TComboBox(FControls[Index]).ItemIndex of
          1: FConfiguration.SetText(Spec.Section, Spec.Name, 'high');
          2: FConfiguration.SetText(Spec.Section, Spec.Name, 'highest');
        else
          FConfiguration.SetText(Spec.Section, Spec.Name, 'low');
        end;
      end
      else if Spec.Name = 'Profile' then begin
        case TComboBox(FControls[Index]).ItemIndex of
          1: FConfiguration.SetText(Spec.Section, Spec.Name, 'screen');
          2: FConfiguration.SetText(Spec.Section, Spec.Name, 'ebook');
          3: FConfiguration.SetText(Spec.Section, Spec.Name, 'printer');
          4: FConfiguration.SetText(Spec.Section, Spec.Name, 'prepress');
          5: FConfiguration.SetText(Spec.Section, Spec.Name, 'custom');
        else
          FConfiguration.SetText(Spec.Section, Spec.Name, 'none');
        end;
      end
      else
        FConfiguration.SetText(Spec.Section, Spec.Name, TComboBox(FControls[Index]).Text);
      Continue;
    end;
    case Spec.Kind of
      okBoolean: FConfiguration.SetBoolean(Spec.Section, Spec.Name, TCheckBox(FControls[Index]).Checked);
      okInteger: FConfiguration.SetInteger(Spec.Section, Spec.Name, TSpinEdit(FControls[Index]).Value);
      okText: FConfiguration.SetText(Spec.Section, Spec.Name, TEdit(FControls[Index]).Text);
    end;
  end;
  FConfiguration.Save;
  ModalResult := mrOk;
end;

procedure TOptionsForm.RestoreClick(Sender: TObject);
var
  Index: Integer;
  Spec: TOptionSpec;
begin
  if FReadOnly then
    Exit;
  for Index := 0 to High(FControls) do begin
    if FControls[Index] = nil then
      Continue;
    Spec := OptionSpec(Index);
    if FControls[Index] is TComboBox then begin
      if Spec.Name = 'ProcessPriority' then
        TComboBox(FControls[Index]).ItemIndex := 2
      else if Spec.Name = 'Level' then
        TComboBox(FControls[Index]).ItemIndex := 5
      else
        TComboBox(FControls[Index]).ItemIndex := 0;
    end
    else if Spec.Kind = okBoolean then
      TCheckBox(FControls[Index]).Checked := SameText(Spec.DefaultValue, 'true')
    else if Spec.Kind = okInteger then
      TSpinEdit(FControls[Index]).Value := StrToIntDef(Spec.DefaultValue, 0)
    else
      TEdit(FControls[Index]).Text := Spec.DefaultValue;
  end;
end;

end.
