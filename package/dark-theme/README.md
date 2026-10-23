# DarkTheme

`DarkTheme` applies a dark color scheme to Windows LCL applications. `DarkThemeLazarus` depends on it and applies the theme to the Lazarus IDE.

Open `darkthemelazarus.lpk` in Lazarus and install it to theme the IDE. Application projects should require `DarkTheme` and point their package dependency at this repository's `darktheme.lpk`. The IDE package is not required by applications.

Call `ApplyDarkTheme(DefaultDark)` from `uDarkTheme` before `Application.Initialize`. Repeated calls are safe; a later call with another `TDSColors` updates the active colors. The application must opt into dark mode, for example by setting `PreferredAppMode := pamForceDark` first.

## Control gallery

Build `test/darktheme_gallery.lpi` with `lazbuild`, then run the gallery to inspect selection, focus, enabled state, menus, and color changes. The **Toggle lists enabled** button covers the ListView and ListBox disabled state. The **Switch colors** button exercises live scheme updates.

Run `darktheme_gallery.exe --self-test` to repeat initialization, switch colors 20 times, recreate the form 30 times, and check that the GDI object count remains bounded. `--self-test-plain` runs the same form cycle without applying the theme for comparison.
