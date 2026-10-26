# Doom Launcher

Doom Launcher is a Windows front end for starting a Doom source port with an IWAD, ordered mods, and saved launch options. Supply your own engine and game data; neither is included.

## Use

1. Open **File → Manage Data Folders** and add a folder containing your game WADs and mods. The launcher also scans directories named by `DOOMWADDIR` and `DOOMWADPATH`.
2. Under **Engine**, add the source port executable. Select an engine and a **Base Game (IWAD)** from the scanned files.
3. Create a **Profile**, move desired mods from **Available WADs** to **Selected WADs**, and use **Up** and **Down** to set their load order. The scanner recognizes `.wad`, `.pk3`, and `.zip` files.
4. Set **Launch Options** or enter extra **Command Line Arguments**, then select **Save Profile** and **Run**. Right-click **Run** to inspect and copy the generated arguments.

Profiles can be duplicated, renamed, locked against edits, imported, and exported through the **File** menu. **Refresh WADs** rescans your folders. The launcher passes a `-savedir` under `saves/<profile name>` beside the executable; an unnamed run uses `saves/_unsorted`. Keep the launcher in a writable location if you want to save settings and game progress there.

Settings are stored in `doom-launcher.ini` beside the executable. Start the launcher with `-ini <path>` to use a different settings file. You can choose absolute paths for engine and data folder entries; otherwise paths are stored relative to the launcher.

## Build it yourself

Install Lazarus with Free Pascal and the Windows LCL widgetset. Register this repository's [`DarkTheme`](../package/dark-theme/README.md) package in Lazarus so the project dependency resolves. From this directory, using your normal Lazarus configuration, run:

```powershell
lazbuild --build-mode=Default doom_launcher.lpi
```

The executable is `doom-launcher.exe` in this directory. The repository's `task build:doom-launcher` runs the same project build and moves the executable to `.dist` at the repository root; its tool paths are configured for the maintainer's machine, so adjust them locally before using that task.

## For developers

`ui/` contains the forms and their event handlers. `models/` defines engines, WAD metadata, profiles, and settings. `services/` scans WADs, resolves paths, builds process arguments, and imports or exports profiles. `configuration/` reads and writes the launcher INI file. Keep changes to launch flags in `services/launch_service.pas` and changes to stored fields in `configuration/launcher_configuration.pas` together.
