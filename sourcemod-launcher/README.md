# Sourcemod Launcher

A Windows Lazarus launcher for mods using **Source SDK Base 2013 Singleplayer** (Steam App ID `243730`). It starts `hl2.exe` directly instead of opening the mod through the Steam Library. Steam and the SDK must still be installed; this does not remove the engine's Steam dependency.

## Use

Run `sourcemod_launcher.exe`, select a mod, and click **Play**. **Refresh** rescans installations and preserves the selected mod when possible. Hover over a list item to see its absolute directory. **Settings → Exit after launching a source mod** controls whether the launcher closes after successfully starting the game process and saving settings.

Steam is located through the Windows registry. The launcher reads `steamapps/libraryfolders.vdf`, locates the SDK through `appmanifest_243730.acf`, and searches direct children of each library's `steamapps/sourcemods` directory. Only mods whose `GameInfo.FileSystem.SteamAppId` is `243730` appear. Mods with `GameInfo.mapbase_core=1` are excluded. Malformed or unreadable metadata files are skipped and counted in the status bar. No Steam or mod files are edited.

The executable receives these arguments, with the SDK directory as its working directory:

```text
-game sourcetest -steam -game "<absolute mod directory>"
```

Starting a process does not guarantee that the game finishes loading. Missing mounted content, mod binaries, or Steam requirements can still cause the game to exit.

## Settings

Settings are stored beside the executable using its name with an `.ini` extension. For example, `SourcemodLauncher.exe` uses `SourcemodLauncher.ini`. To use another file:

```powershell
.\sourcemod_launcher.exe -ini "C:\Settings\source mods.ini"
```

Relative `-ini` paths are resolved against the startup working directory. The first `-ini` argument takes precedence. A missing path is reported as an error. The destination directory must already exist and be writable.

```ini
[general]
exit_on_launch=1
last_launch=E:\Steam\steamapps\sourcemods\noclip
```

The default is `exit_on_launch=1` and an empty `last_launch`. Boolean values are saved as `1` or `0`; `true` and `false` are also accepted when reading. The menu saves changes immediately. `last_launch` records the absolute directory only after a process starts successfully; that mod is selected next time. If it has disappeared, the first available mod is selected. Settings errors leave the launcher open. A file that cannot be read is not overwritten.

## Icons

Following the [Valve Developer Community gameinfo.txt documentation](https://developer.valvesoftware.com/wiki/Gameinfo.txt), `GameInfo.icon` is a mod-relative path without an extension. The launcher appends `.tga` and loads an uncompressed 16×16 true-color TGA in memory, supporting 24-bit RGB and 32-bit RGBA. Active eight-bit alpha is preserved. Paths outside the mod directory are rejected. PNG and ICO alternatives and the 32px `_big.tga` variant are not searched.

Missing, empty, unsupported, or damaged icons use the embedded `resource/hl2.png`. This image was supplied by the user from `E:\DOWNLOAD\asset\hl2.png`, extracted from the SDK's `hl2.exe`. The Play button uses the user-supplied `E:\DOWNLOAD\asset\play-32.png`, copied as `resource/play.png`. Both PNGs are embedded as RCDATA; deployment requires only the executable. No icon is extracted or converted on disk at runtime.

## Build and checks

Install Lazarus with Free Pascal and the Windows widgetset. Register this repository's [DarkTheme](../package/dark-theme/README.md) and [RuntimeResource](../package/runtime-resource/README.md) packages in the same Lazarus configuration used by the IDE.

From this directory:

```powershell
lazbuild --pcp="$env:LOCALAPPDATA\lazarus" --build-mode=Default sourcemod_launcher.lpi
lazbuild --pcp="$env:LOCALAPPDATA\lazarus" tests/launcher_tests.lpi
Push-Location tests
.\launcher_tests.exe -ini "$env:TEMP\sourcemod-launcher-tests.ini"
Pop-Location
```

The assertion-based checks cover KeyValues syntax and malformed input, discovery fixtures, filtering, sorting, INI round trips, launch arguments, TGA color and partial alpha, fallback icons, live discovery, form creation, refresh selection, hover paths, and menu persistence. Fixtures and a form capture are left in the printed temporary directory for inspection. Tests do not launch a game. Use a disposable INI path for the checks.

The repository's `task build:sourcemod-launcher` builds and copies the application to `.dist/SourcemodLauncher.exe`; the aggregate `task build` includes it. Adjust the Taskfile's local tool paths if needed.

The form is defined in `ui/main.lfm` using standard LCL controls and RuntimeResource's button so it remains editable in the Lazarus designer. The only image-reader specialization preserves full TGA alpha because Free Pascal 3.2.2's reader otherwise thresholds it.
