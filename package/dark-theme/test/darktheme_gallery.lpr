program darktheme_gallery;

{$MODE objfpc}
{$H+}

uses
  Interfaces,
  Classes,
  Forms,
  Controls,
  StdCtrls,
  ComCtrls,
  Menus,
  ExtCtrls,
  Graphics,
  LCLType,
  Windows,
  uDarkStyleParams,
  uDarkStyleSchemes,
  uDarkTheme;

type
  TGalleryForm = class(TForm)
  private
    ListBox: TListBox;
    ListView: TListView;
    procedure ToggleEnabled(Sender: TObject);
    procedure ToggleScheme(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

function GetGuiResources(hProcess: THandle; uiFlags: DWORD): DWORD; stdcall; external 'user32' name 'GetGuiResources';

constructor TGalleryForm.CreateNew(AOwner: TComponent; Num: Integer);
var
  Button: TButton;
  CheckBox: TCheckBox;
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

procedure TGalleryForm.ToggleEnabled(Sender: TObject);
begin
  ListView.Enabled := not ListView.Enabled;
  ListBox.Enabled := not ListBox.Enabled;
end;

procedure TGalleryForm.ToggleScheme(Sender: TObject);
begin
  if Color = clWhite then begin
    ApplyDarkTheme(DefaultDark);
    Color := DefaultDark.SysColor[COLOR_BTNFACE];
  end
  else begin
    ApplyDarkTheme(DefaultWhite);
    Color := clWhite;
  end;
end;

var
  GalleryForm: TGalleryForm;
  Cycle: Integer;
  InitialGdiCount: DWORD;
  PlainMode: Boolean;
  RecreatedForm: TGalleryForm;
begin
  RequireDerivedFormResource := False;
  PlainMode := (ParamCount = 1) and (ParamStr(1) = '--self-test-plain');
  if not PlainMode then begin
    PreferredAppMode := pamForceDark;
    ApplyDarkTheme(DefaultDark);
    ApplyDarkTheme(DefaultDark);
  end;
  Application.Initialize;
  Application.CreateForm(TGalleryForm, GalleryForm);
  if (ParamCount = 1) and ((ParamStr(1) = '--self-test') or PlainMode) then begin
    GalleryForm.Show;
    if not PlainMode then begin
      GalleryForm.ToggleScheme(nil);
      GalleryForm.ToggleScheme(nil);
    end;
    Application.ProcessMessages;
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
    if GetGuiResources(GetCurrentProcess, 0) > InitialGdiCount + 32 then
      Halt(1);
    GalleryForm.Free;
    Exit;
  end;
  Application.Run;
end.
