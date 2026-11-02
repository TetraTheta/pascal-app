program darktheme_gallery;

{$MODE objfpc}
{$H+}

uses
  Interfaces,
  Classes,
  Types,
  Forms,
  Controls,
  Buttons,
  StdCtrls,
  ComCtrls,
  CommCtrl,
  Menus,
  ExtCtrls,
  Graphics,
  Themes,
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
    ImageButton: TBitBtn;
    ListBox: TListBox;
    ListView: TListView;
    LightColors: Boolean;
    procedure CheckColorSchemes;
    procedure CheckImageButtonCaption;
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
  Glyph: Graphics.TBitmap;
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

  ImageButton := TBitBtn.Create(Self);
  ImageButton.Parent := Self;
  ImageButton.SetBounds(394, 452, 96, 88);
  ImageButton.Caption := 'Play';
  ImageButton.Layout := blGlyphTop;
  Glyph := Graphics.TBitmap.Create;
  try
    Glyph.SetSize(32, 32);
    Glyph.Canvas.Brush.Color := clFuchsia;
    Glyph.Canvas.FillRect(0, 0, 32, 32);
    Glyph.Canvas.Brush.Color := clWhite;
    Glyph.Canvas.Pen.Color := clWhite;
    Glyph.Canvas.Polygon([Types.Point(8, 4), Types.Point(27, 16), Types.Point(8, 28)]);
    Glyph.TransparentColor := clFuchsia;
    Glyph.Transparent := True;
    ImageButton.Glyph.Assign(Glyph);
  finally
    Glyph.Free;
  end;

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
  ButtonDetails: TThemedElementDetails;
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
      CheckImageButtonCaption;
      ButtonDetails := ThemeServices.GetElementDetails(tbPushButtonNormal);
      if ThemeServices.ColorToRGB(clBtnText, @ButtonDetails) <> ColorToRGB(Scheme.SysColor[COLOR_BTNTEXT]) then begin
        WriteLn(StdErr, 'Themed button text does not match the active palette at cycle ', Cycle);
        Halt(5);
      end;
      if (ThemeServices.ColorToRGB(clGrayText, @ButtonDetails) <> ColorToRGB(Scheme.SysColor[COLOR_GRAYTEXT]))
          or (ThemeServices.ColorToRGB(clRed, @ButtonDetails) <> ColorToRGB(clRed)) then
        Halt(5);
      if (GetObject(CachedBrush.Handle, SizeOf(BrushData), @BrushData) = 0)
          or (BrushData.lbColor <> ColorToRGB(Scheme.SysColor[COLOR_WINDOW]))
          or (ColorToRGB(ListBox.Color) <> ColorToRGB(Scheme.SysColor[COLOR_WINDOW]))
          or (ColorToRGB(Color) <> ColorToRGB(Scheme.SysColor[COLOR_BTNFACE]))
          or (ColorToRGB(Font.Color) <> ColorToRGB(Scheme.SysColor[COLOR_BTNTEXT]))
          or (ListView_GetBkColor(ListView.Handle) <> ColorToRGB(Scheme.SysColor[COLOR_WINDOW])) then
      begin
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

procedure TGalleryForm.CheckImageButtonCaption;
var
  Bitmap: Graphics.TBitmap;
  Images: BUTTON_IMAGELIST;
  X, Y, W, H, State: Integer;
  Expected, Background, Pixel: TColor;
  FoundText: Boolean;
begin
  Images := Default(BUTTON_IMAGELIST);
  if SendMessage(ImageButton.Handle, BCM_GETIMAGELIST, 0, LPARAM(@Images)) = 0 then
    Halt(5);
  ImageList_GetIconSize(Images.himl, W, H);
  Bitmap := Graphics.TBitmap.Create;
  try
    Bitmap.SetSize(W, H);
    Bitmap.Canvas.Brush.Color := clBtnFace;
    Expected := ColorToRGB(clBtnText);
    Background := ColorToRGB(clBtnFace);
    // Inspect actual caption pixels cached by LCL for normal, hot, pressed and disabled states.
    for State := 0 to 3 do begin
      Bitmap.Canvas.FillRect(0, 0, W, H);
      ImageList_Draw(Images.himl, State, Bitmap.Canvas.Handle, 0, 0, ILD_NORMAL);
      FoundText := False;
      for Y := ImageButton.Glyph.Height + ImageButton.Spacing to H - 1 do
        for X := 0 to W - 1 do begin
          Pixel := ColorToRGB(Bitmap.Canvas.Pixels[X, Y]);
          if ((State <> 3) and (Pixel = Expected)) or ((State = 3) and (Pixel <> Background)) then
            FoundText := True;
        end;
      if not FoundText then begin
        Bitmap.SaveToFile(GetTempDir + 'darktheme-button-text.bmp');
        WriteLn(StdErr, 'Image button caption color failed for state ', State);
        Halt(5);
      end;
    end;
  finally
    Bitmap.Free;
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
  ImageButton.Enabled := not ImageButton.Enabled;
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
