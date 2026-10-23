unit uDarkTheme;

{$mode objfpc}{$H+}

interface

{$IFDEF WINDOWS}
uses
    {IF DEFINED(LCLQT5)}
      uDarkStyle,
    {ENDIF}
    uDarkStyleParams,
    {$IFDEF LCLWIN32}
    uWin32WidgetSetDark,
    {$ENDIF}
    uDarkStyleSchemesLoader;
{$ENDIF}

{$IFDEF WINDOWS}
procedure ApplyDarkTheme(const CS:TDSColors);
{$ENDIF}
procedure DarkThemeFormChanged(Form: TObject);

implementation

{$IFDEF WINDOWS}
var
  StyleApplied: Boolean = False;

procedure ApplyDarkTheme(const CS:TDSColors);
begin
  if StyleApplied then
  begin
    {$IFDEF LCLWIN32}SetColorsScheme(CS);{$ENDIF}
    Exit;
  end;
  InitDarkMode;
  Initialize(CS);
  if IsDarkModeEnabled then
  begin
    ApplyDarkStyle;
    StyleApplied:= True;
  end;
end;
{$ENDIF}

procedure DarkThemeFormChanged(Form: TObject);
begin
  {$IFDEF LCLWIN32}DarkFormChanged(Form);{$ENDIF}
end;
end.
