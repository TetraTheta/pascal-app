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
