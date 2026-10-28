# Hammer Launcher

Hammer Launcher opens a configured Hammer or Hammer++ editor for Half-Life 2, Garry's Mod, or Entropy: Zero 2. It can pass a map file to the selected editor.

## Use

1. Run `hammer_launcher.exe` once. It creates `hammer_launcher.ini` beside the executable.
2. Edit the INI file and set the executable paths and optional arguments for the editors you have installed. For example:

   ```ini
   [hl2]
   stock=C:\Program Files (x86)\Steam\steamapps\common\Half-Life 2\bin\hammer.exe
   stockargs=
   custom=C:\Program Files (x86)\Steam\steamapps\common\Half-Life 2\bin\hammerplusplus.exe
   customargs=
   [gmod]
   stock=
   stockargs=
   custom=
   customargs=
   [ez2]
   stock=
   stockargs=
   custom=
   customargs=
   ```

3. Restart the launcher. Buttons with valid executable paths become enabled. Choose the editor by clicking its button, or press `1` through `6` in row order. The launcher exits after opening the editor.

To pass a map to Hammer, start `hammer_launcher.exe "C:\Maps\example.vmf"`. The target field displays that path; it is read-only. The editor receives any configured `stockargs` or `customargs` first, followed by the map path. Separate arguments with spaces and quote an argument that contains spaces. The launcher does not search for editor installations or edit paths in the window.

## Build it yourself

Install Lazarus with Free Pascal and the Windows LCL widgetset. Register this repository's [`DarkTheme`](../package/dark-theme/README.md) and [`RuntimeResource`](../package/runtime-resource/README.md) packages in Lazarus. From this directory, run:

```powershell
lazbuild --build-mode=Default hammer_launcher.lpi
```

The executable is `hammer_launcher.exe` in this directory. The repository's `task build:hammer-launcher` builds it and places it at `.dist/HammerLauncher.exe`; adjust the Taskfile's local tool paths before using that task. With the renamed executable, its settings file is `HammerLauncher.ini`.

## For developers

`configuration/launcher_configuration.pas` defines and loads the twelve INI entries. `ui/main.pas` handles enabled buttons, keyboard shortcuts, and process launch; `ui/main.lfm` defines their layout. `resource/images.rc` embeds the button images through RuntimeResource, so keep resource names in the form and RC file aligned.
