program darktheme_gallery;

{$MODE objfpc}
{$H+}

uses
  Interfaces,
  Classes,
  Types,
  Forms,
  Controls,
  StdCtrls,
  ComCtrls,
  CommCtrl,
  Menus,
  ExtCtrls,
  Graphics,
  SysUtils,
  UxTheme,
  TmSchema,
  uImport,
  LCLType,
  Windows,
  uDarkStyleParams,
  uDarkStyleSchemes,
  uDarkTheme;

{$R *.res}

type
  TGalleryForm = class(TForm)
  private
    CheckBox: TCheckBox;
    ListBox: TListBox;
    ListView: TListView;
    LightColors: Boolean;
    procedure CheckColorSchemes;
    procedure CheckSharedButtonTheme;
    procedure ToggleEnabled(Sender: TObject);
    procedure ToggleScheme(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

function GetGuiResources(hProcess: THandle; uiFlags: DWORD): DWORD; stdcall; external 'user32' name 'GetGuiResources';

constructor TGalleryForm.CreateNew(AOwner: TComponent; Num: Integer);
var
  Button: TButton;
  ComboBox: TComboBox;
  Edit: TEdit;
  GroupBox: TGroupBox;
  Item: TListItem;
  MainMenu: TMainMenu;
  Memo: TMemo;
  MenuItem: TMenuItem;
  PageControl: TPageControl;
  GalleryPopupMenu: TPopupMenu;
  RadioButton: TRadioButton;
  ScrollBar: TScrollBar;
  StatusBar: TStatusBar;
  TabSheet: TTabSheet;
begin
  inherited CreateNew(AOwner, Num);
  Caption := 'DarkTheme control gallery';
  Width := 800;
  Height := 650;

  MainMenu := TMainMenu.Create(Self);
  MenuItem := TMenuItem.Create(MainMenu);
  MenuItem.Caption := 'Gallery';
  MainMenu.Items.Add(MenuItem);
  Menu := MainMenu;

  GalleryPopupMenu := TPopupMenu.Create(Self);
  MenuItem := TMenuItem.Create(GalleryPopupMenu);
  MenuItem.Caption := 'Popup item';
  GalleryPopupMenu.Items.Add(MenuItem);

  Button := TButton.Create(Self);
  Button.Parent := Self;
  Button.SetBounds(12, 12, 160, 30);
  Button.Caption := 'Toggle lists enabled';
  Button.OnClick := @ToggleEnabled;

  Button := TButton.Create(Self);
  Button.Parent := Self;
  Button.SetBounds(180, 12, 160, 30);
  Button.Caption := 'Switch colors';
  Button.OnClick := @ToggleScheme;

  ListView := TListView.Create(Self);
  ListView.Parent := Self;
  ListView.SetBounds(12, 52, 370, 200);
  ListView.ViewStyle := vsReport;
  ListView.RowSelect := True;
  ListView.Columns.Add.Caption := 'Name';
  ListView.Columns.Add.Caption := 'Value';
  Item := ListView.Items.Add;
  Item.Caption := 'Selected row';
  Item.SubItems.Add('One');
  ListView.Items.Add.Caption := 'Unselected row';
  ListView.Selected := Item;
  ListView.PopupMenu := GalleryPopupMenu;

  ListBox := TListBox.Create(Self);
  ListBox.Parent := Self;
  ListBox.SetBounds(394, 52, 370, 200);
  ListBox.Items.Add('Selected row');
  ListBox.Items.Add('Unselected row');
  ListBox.ItemIndex := 0;

  GroupBox := TGroupBox.Create(Self);
  GroupBox.Parent := Self;
  GroupBox.SetBounds(12, 265, 370, 175);
  GroupBox.Caption := 'Basic controls';

  CheckBox := TCheckBox.Create(Self);
  CheckBox.Parent := GroupBox;
  CheckBox.SetBounds(12, 25, 120, 25);
  CheckBox.Caption := 'Checked';
  CheckBox.Checked := True;

  RadioButton := TRadioButton.Create(Self);
  RadioButton.Parent := GroupBox;
  RadioButton.SetBounds(150, 25, 120, 25);
  RadioButton.Caption := 'Radio';
  RadioButton.Checked := True;

  Edit := TEdit.Create(Self);
  Edit.Parent := GroupBox;
  Edit.SetBounds(12, 60, 160, 28);
  Edit.Text := 'Edit';

  ComboBox := TComboBox.Create(Self);
  ComboBox.Parent := GroupBox;
  ComboBox.SetBounds(185, 60, 160, 28);
  ComboBox.Items.Add('Combo item');
  ComboBox.ItemIndex := 0;

  Memo := TMemo.Create(Self);
  Memo.Parent := GroupBox;
  Memo.SetBounds(12, 100, 333, 58);
  Memo.Lines.Text := 'Memo';

  PageControl := TPageControl.Create(Self);
  PageControl.Parent := Self;
  PageControl.SetBounds(394, 265, 370, 175);
  TabSheet := TTabSheet.Create(Self);
  TabSheet.PageControl := PageControl;
  TabSheet.Caption := 'Tab';

  ScrollBar := TScrollBar.Create(Self);
  ScrollBar.Parent := TabSheet;
  ScrollBar.SetBounds(15, 25, 300, 20);

  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.SimpleText := 'Check focus, selection, enabled state, menus and colors.';
end;

procedure TGalleryForm.CheckColorSchemes;
var
  CachedBrush: TBrush;
  DormantBrush: TBrush;
  BrushData: TLogBrush;
  Cycle: Integer;
  Scheme: TDSColors;
begin
  CachedBrush := TBrush.Create;
  DormantBrush := TBrush.Create;
  try
    DormantBrush.Color := clWindow;
    GetObject(DormantBrush.Handle, SizeOf(BrushData), @BrushData);
    CachedBrush.Color := clWindow;
    GetObject(CachedBrush.Handle, SizeOf(BrushData), @BrushData);
    for Cycle := 1 to 4 do begin
      if Odd(Cycle) then
        Scheme := DefaultWhite
      else
        Scheme := DefaultDark;
      ToggleScheme(nil);
      Application.ProcessMessages;
      if (GetObject(CachedBrush.Handle, SizeOf(BrushData), @BrushData) = 0)
          or (BrushData.lbColor <> ColorToRGB(Scheme.SysColor[COLOR_WINDOW]))
          or (ColorToRGB(ListBox.Color) <> ColorToRGB(Scheme.SysColor[COLOR_WINDOW]))
          or (ColorToRGB(Color) <> ColorToRGB(Scheme.SysColor[COLOR_BTNFACE]))
          or (ColorToRGB(Font.Color) <> ColorToRGB(Scheme.SysColor[COLOR_BTNTEXT]))
          or (ListView_GetBkColor(ListView.Handle) <> ColorToRGB(Scheme.SysColor[COLOR_WINDOW])) then begin
        WriteLn(StdErr, 'Color scheme did not reach cached brushes and controls at cycle ', Cycle);
        Halt(5);
      end;
    end;
    if (GetObject(DormantBrush.Handle, SizeOf(BrushData), @BrushData) = 0)
        or (BrushData.lbColor <> ColorToRGB(DefaultDark.SysColor[COLOR_WINDOW])) then
      Halt(5);
  finally
    DormantBrush.Free;
    CachedBrush.Free;
  end;
end;

procedure TGalleryForm.CheckSharedButtonTheme;
var
  BeforeClose: Graphics.TBitmap;
  AfterClose: Graphics.TBitmap;
  SharedTheme: HTHEME;
  OtherTheme: HTHEME;
  Module: HMODULE;
  Entry: PPointer;
  Imports: Pointer;
  Bounds: TRect;
  CloseTheme: function(Theme: HTHEME): HRESULT; stdcall;
  DrawBackground: function(Theme: HTHEME; DC: HDC; Part, State: Integer; const Rect: TRect; Clip: Pointer): HRESULT; stdcall;
begin
  if not IsDarkModeEnabled then
    Halt(4);
  BeforeClose := Graphics.TBitmap.Create;
  AfterClose := Graphics.TBitmap.Create;
  try
    BeforeClose.SetSize(CheckBox.Width, CheckBox.Height);
    AfterClose.SetSize(CheckBox.Width, CheckBox.Height);
    BeforeClose.Canvas.Brush.Color := Color;
    BeforeClose.Canvas.FillRect(0, 0, CheckBox.Width, CheckBox.Height);
    AfterClose.Canvas.Draw(0, 0, BeforeClose);
    Module := GetModuleHandle('comctl32.dll');
    Imports := FindDelayImportLibrary(Module, 'uxtheme.dll');
    if Imports = nil then
      raise Exception.Create('The themed common controls library is unavailable');
    Entry := FindDelayImportFunction(Module, Imports, 'DrawThemeBackground');
    if Entry = nil then
      raise Exception.Create('The native theme drawing hook is unavailable');
    Pointer(DrawBackground) := Entry^;
    Entry := FindDelayImportFunction(Module, Imports, 'CloseThemeData');
    if Entry = nil then
      raise Exception.Create('The native theme close entry is unavailable');
    Pointer(CloseTheme) := Entry^;
    Bounds := Types.Rect(0, 0, CheckBox.Width, CheckBox.Height);
    SharedTheme := UxTheme.OpenThemeData(0, 'Button');
    OtherTheme := UxTheme.OpenThemeData(0, 'Button');
    if (SharedTheme = 0) or (OtherTheme = 0) then
      raise Exception.Create('Could not open the shared button theme');
    try
      if SharedTheme <> OtherTheme then
        Halt(3);
      DrawBackground(SharedTheme, BeforeClose.Canvas.Handle, BP_CHECKBOX, CBS_CHECKEDNORMAL, Bounds, nil);
      // Closing one reference must preserve custom drawing for the other reference.
      CloseTheme(OtherTheme);
      DrawBackground(SharedTheme, AfterClose.Canvas.Handle, BP_CHECKBOX, CBS_CHECKEDNORMAL, Bounds, nil);
    finally
      UxTheme.CloseThemeData(SharedTheme);
    end;
    if not BeforeClose.Equals(AfterClose) then
      Halt(2);
  finally
    AfterClose.Free;
    BeforeClose.Free;
  end;
end;

procedure TGalleryForm.ToggleEnabled(Sender: TObject);
begin
  ListView.Enabled := not ListView.Enabled;
  ListBox.Enabled := not ListBox.Enabled;
end;

procedure TGalleryForm.ToggleScheme(Sender: TObject);
begin
  if LightColors then
    ApplyDarkTheme(DefaultDark)
  else
    ApplyDarkTheme(DefaultWhite);
  LightColors := not LightColors;
end;

var
  GalleryForm: TGalleryForm;
  Cycle: Integer;
  InitialGdiCount: DWORD;
  PlainMode: Boolean;
  RecreatedForm: TGalleryForm;
begin
  Application.CaptureExceptions := False;
  RequireDerivedFormResource := False;
  PlainMode := (ParamCount = 1) and (ParamStr(1) = '--self-test-plain');
  if not PlainMode then begin
    PreferredAppMode := pamForceDark;
    ApplyDarkTheme(DefaultDark);
    ApplyDarkTheme(DefaultDark);
  end;
  Application.Initialize;
  Application.CreateForm(TGalleryForm, GalleryForm);
  if (ParamCount = 1) and (ParamStr(1) = '--self-test-colors') then begin
    GalleryForm.Show;
    Application.ProcessMessages;
    GalleryForm.CheckColorSchemes;
    GalleryForm.Free;
    Exit;
  end;
  if (ParamCount = 1) and (ParamStr(1) = '--self-test-theme') then begin
    GalleryForm.Show;
    Application.ProcessMessages;
    GalleryForm.CheckSharedButtonTheme;
    GalleryForm.Free;
    Exit;
  end;
  if (ParamCount = 1) and ((ParamStr(1) = '--self-test') or PlainMode) then begin
    GalleryForm.Show;
    if not PlainMode then begin
      GalleryForm.ToggleScheme(nil);
      GalleryForm.ToggleScheme(nil);
    end;
    Application.ProcessMessages;
    if not PlainMode then begin
      GalleryForm.CheckColorSchemes;
      GalleryForm.CheckSharedButtonTheme;
    end;
    InitialGdiCount := GetGuiResources(GetCurrentProcess, 0);
    for Cycle := 1 to 20 do begin
      GalleryForm.ToggleEnabled(nil);
      if not PlainMode then
        GalleryForm.ToggleScheme(nil);
      Application.ProcessMessages;
    end;
    for Cycle := 1 to 30 do begin
      RecreatedForm := TGalleryForm.CreateNew(nil);
      try
        RecreatedForm.Show;
        Application.ProcessMessages;
      finally
        RecreatedForm.Free;
      end;
    end;
    if GetGuiResources(GetCurrentProcess, 0) > InitialGdiCount + 32 then begin
      WriteLn(StdErr, 'GDI objects: ', InitialGdiCount, ' -> ', GetGuiResources(GetCurrentProcess, 0));
      Halt(1);
    end;
    GalleryForm.Free;
    Exit;
  end;
  Application.Run;
end.
