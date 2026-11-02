# DarkTheme

`DarkTheme` applies a dark color scheme to Windows Lazarus LCL applications. `DarkThemeLazarus` is an optional package that applies the theme to the Lazarus IDE.

## Use

Open `darkthemelazarus.lpk` in Lazarus and install it if you want to theme the IDE. Application projects should require `DarkTheme` and point their package dependency at this repository's `darktheme.lpk`.

Call `ApplyDarkTheme(DefaultDark)` from `uDarkTheme` before `Application.Initialize`. Repeated calls are safe; a later call with another `TDSColors` updates the active colors. The application must opt into dark mode, for example by setting `PreferredAppMode := pamForceDark` first.

## Build it yourself

Install Lazarus with Free Pascal and the Windows LCL widgetset. From this directory, run:

```powershell
lazbuild darktheme.lpk
```

For the IDE theme, open `darkthemelazarus.lpk` in Lazarus and use **Install** to rebuild the IDE. These packages produce compiled package units, not a standalone program. The application projects in this repository list `DarkTheme` as a required package; `Taskfile.yml` builds it as a dependency when needed but has no separate package task. Use your normal Lazarus primary configuration so installed packages can be resolved.

## For developers

`src/udarktheme.pas` exposes `ApplyDarkTheme`; `src/udarkstyle*.pas` and `src/uwin32widgetsetdark.pas` implement the Windows styling. `src/dsgn/` contains the IDE integration. The package entry units and `.lpk` files define what Lazarus compiles and installs.

### Control gallery

Build `test/darktheme_gallery.lpi` with `lazbuild`, then run the gallery to inspect selection, focus, enabled state, menus, and color changes. The **Toggle lists enabled** button covers the ListView and ListBox disabled state. The **Switch colors** button exercises live scheme updates.

Run `darktheme_gallery.exe --self-test` to repeat initialization, switch colors 20 times, recreate the form 30 times, and check that the GDI object count remains bounded. `--self-test-plain` runs the same form cycle without applying the theme for comparison.

Run `darktheme_gallery.exe --self-test-theme` to verify that closing one reference to a shared Windows button theme preserves checkbox drawing through the native common-controls hooks. Exit codes are 2 for changed rendering, 3 if Windows does not share the tested handles, and 4 if dark mode is unavailable. The same check runs as part of `--self-test`. The gallery includes its manifest resource so it uses themed common controls like the application projects.

Run `darktheme_gallery.exe --self-test-colors` to switch from dark to light colors and back twice, checking cached system brushes, form/list colors, and the native ListView background. It also checks a brush left unused across the switches and themed button text colors, including gray text and preservation of explicit RGB colors. The gallery includes a Play button with a glyph above its caption; the check inspects its actual cached caption pixels for normal, hovered, pressed, and disabled states after each palette switch. **Toggle lists enabled** also toggles this button. Failed caption checks save `darktheme-button-text.bmp` in the temporary directory. A color mismatch returns exit code 5. This check also runs in `--self-test`. Color schemes change the package palette; Windows dark mode remains enabled.
