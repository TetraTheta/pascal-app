# GMod Description Generator

GMod Description Generator creates Steam-style BBCode for a Garry's Mod add-on description. It prepares text for copying; it does not publish to Steam.

## Use

1. Enter a title, author, description, synopsis, and map names. Use one map per line.
2. Select the mounted-game requirements and other options that apply to the add-on. Adjust the release date, or select **No Release Date**.
3. Click **Generate** to fill **Preview**, then **Copy** to copy the generated text to the clipboard.

The output includes fixed recommendations and a disclaimer in addition to your entries, so review the preview before publishing it. **Reset** clears the form after confirmation. **File → Save** stores your inputs as JSON; **File → Open** restores them. You can also drop one `.json` file onto the window. `Ctrl+O` and `Ctrl+S` open and save. The JSON file is a settings file, not the generated BBCode.

## Build it yourself

Install Lazarus with Free Pascal and the Windows LCL widgetset. Register this repository's [`DarkTheme`](../package/dark-theme/README.md) package in Lazarus. From this directory, run:

```powershell
lazbuild --build-mode=Default gmod_description_generator.lpi
```

The executable is `gmod_description_generator.exe` in this directory. The repository's `task build:gmod-description-generator` builds it and moves it to `.dist/GModDescriptionGenerator.exe`; adjust the Taskfile's local tool paths before using that task.

## For developers

`ui/main.pas` contains BBCode generation, JSON persistence, and date validation; `ui/main.lfm` defines the form. The JSON field names in `BuildSettingsJson` and `OpenFile` form the saved-file format, so update both when adding an input. The generated recommendation and disclaimer text is currently embedded in `ButtonGenerateClick`.
