# User guide

## Add and optimize files

Drag files or folders onto the window, or use **Add files** and **Add folder**. Folders are scanned recursively. Select **Optimize all** to process the list. Each file goes through the applicable tools in the `plugin` folder. The application keeps the original when no smaller result is produced.

You can also pass files or folders to `FileOptimizer.exe` on the command line. Processing begins after the configured startup delay, and the application closes when the list is finished. Use `/Level=9` or `/PNGCopyMetadata=true` to override a setting for one run, `/?` for help, and `/NOWINDOW` to hide the main window.

Click a column heading to sort the list. Double-click a file to open it with its associated Windows application. The File menu and context menu also open the selected file or its containing folder.

While optimization is running, file opening and list edits are disabled. The context menu still offers **Stop**, **About**, and **Information**. You can inspect **Options** in read-only mode; changes can be saved after processing finishes.

Double-click a column heading separator to fit that column to its contents. The File column fills the remaining width when the window is resized.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Delete` | Remove selected list entries |
| `F5` | Refresh file sizes |
| `Ctrl+F5` | Remove completed entries and refresh sizes |
| `Ctrl+C` | Copy all listed paths to the clipboard |
| `Ctrl+X` | Copy all listed paths, then clear the list |
| `Ctrl+V` | Replace the list with paths from the clipboard |

## Originals and backups

Optimization runs on temporary copies. A smaller result replaces the original. By default, a copy of the original goes to the Recycle Bin before replacement. In **Options → General**, you can turn off Recycle Bin copies, request separate `.bak` files, or preserve file timestamps and attributes.

Some tools remove metadata. Options that allow lossy image processing can also change image quality. PDF profiles can downsample embedded images, and arithmetic JPEG encoding may require newer image viewers. Minified HTML, CSS, and JavaScript may be harder to edit in visual tools.

## Parallel processing

In **Options → General**, enable parallel processing and choose how many files may run at once. Tools for each individual file still run in order. Higher counts use more CPU and memory. If duplicate paths are allowed in the list, processing runs one file at a time to avoid simultaneous writes to the same file.

**Stop** prevents further files from starting and terminates the currently running tools. Files already completed remain optimized.

## Settings and language

Settings are read first from `%AppData%\FileOptimizer\FileOptimizer.ini`, then from `FileOptimizer.ini` beside the executable. If neither exists, default settings are created in AppData. Changes are saved to AppData. The optimization cache is kept separately in `%AppData%\FileOptimizer\FileOptimizer.Cache.ini`. Common settings are in `[General]`, format-specific settings are in sections such as `[PNG]` and `[PDF]`, and window size and position are in `[Window]`.

Include Mask and Exclude Mask use case-insensitive substrings of the full file path. Separate alternatives with commas, such as `.png,images`. They do not accept regular expressions or wildcards. Disable Plugin Mask likewise searches for case-insensitive substrings in plugin command lines; use executable names such as `oxipng.exe,pingo.exe`.

Log Level 0 writes nothing. The current implementation has no entries for levels 1–3. Level 4 appends executed plugin commands, exit codes, and file sizes to `FileOptimizer.log` beside the executable. There is no log window. If no plugin executable is installed, optimization reports this before starting; a file with no applicable executable is marked Skipped with a reason.

English is built in. Korean is loaded from `lang/ko.ini` when the system language is Korean or `General.Language=ko` is selected. Missing translations fall back to English.
