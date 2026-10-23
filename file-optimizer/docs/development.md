# Developer guide

## Build and project layout

Open `file_optimizer.lpi` in Lazarus or run `lazbuild file_optimizer.lpi` with the normal Lazarus primary configuration path. The default target is Windows x64 and the output is `FileOptimizer.exe`.

- `configuration/optimizer_configuration.pas` defines the INI keys and defaults.
- `services/optimizer_service.pas` owns the file queue, per-file workers, temporary copies, CLI processes, cache, and replacement.
- `services/optimizer_service.pas` also defines the recognized extension sets and format-specific tool order. Each `RunPlugin` call belongs to the preceding format condition.
- `ui/main_form.pas` and `ui/options_form.pas` implement behavior; their `.lfm` files define the editable form layouts. Lazarus needs the installed `DarkTheme` package for the dark theme.
- `lang/ko.ini` supplies Korean strings; English defaults are in the Pascal source.

The tool chain for one file is sequential. Parallel workers handle different files. A plugin result is adopted only when its exit code is accepted and its output is at least eight bytes and smaller than the current working copy. The final working copy replaces the original only when it is smaller. Missing tools are skipped. Options and file characteristics can skip individual steps.

## Tool order by format

Names below are executable names in `plugin`. An arrow means the next attempted step for the same file, subject to the conditions in `RunFormatPlugins`. The table is useful when deciding whether an installed executable is called directly.

| Format group | Tool sequence |
| --- | --- |
| AVIF | `magick.exe` |
| BMP | `magick.exe` → `imagew.exe` |
| CSS | `csstidy.exe` → `minify.exe` |
| DLL | `petrim.exe` → `strip.exe` → `upx.exe` |
| EXE | `leanify.exe` → `petrim.exe` → `strip.exe` → `upx.exe` |
| FLAC | `shntool.exe` (strip) → `shntool.exe` (trim) → `flac.exe` → `flacout.exe` |
| GIF | `magick.exe` → `gifsicle.exe` |
| GZ | `gzip.exe` → `leanify.exe` → `advdef.exe` → `zRecompress.exe` → `ECT.exe` → `deflopt.exe` → `defluff.exe` → `deflopt.exe` |
| HTML | `tidy.exe` → `minify.exe` → `leanify.exe` |
| ICO | `leanify.exe` |
| JP2 | `magick.exe` |
| JPEG | `pingo.exe` → `cjpegli.exe` → `guetzli.exe` → `jpeg-recompress.exe` → `jhead.exe` → `leanify.exe` → `magick.exe` → `jpegoptim.exe` → `jpegtran.exe` → `mozjpegtran.exe` → `ECT.exe` |
| JXL | `magick.exe` |
| JS and configured JS extensions | `jsmin.exe` → `minify.exe` |
| LUA | `leanify.exe` |
| MIME | `leanify.exe` |
| MKV | `ffmpeg.exe` → `mkclean.exe` |
| MNG | `advmng.exe` |
| MP3 | `mp3packer.exe` |
| MP4 | `ffmpeg.exe` → `mp4file.exe` |
| OBJ | `strip.exe` |
| OGG | `optivorbis.exe` → `rehuff_theora.exe` |
| OGV | `ffmpeg.exe` → `rehuff_theora.exe` |
| OLE | `docprc.exe` → `bestcfbf.exe` |
| PCX | `magick.exe` |
| PDF | `mutool.exe` → `gswin64c.exe` → `cpdf.exe` → `qpdf.exe` |
| PNG | `apngopt.exe` → `pngquant.exe` → `PngOptimizer.exe` → `truepng.exe` → `pngout.exe` → `oxipng.exe` → `oxipng.exe` → `leanify.exe` → `pngwolf.exe` → `pngrewrite.exe` → `advpng.exe` → `ECT.exe` → `pingo.exe` → `deflopt.exe` → `defluff.exe` → `deflopt.exe` |
| SWF | `flasm.exe` (extract) → `flasm.exe` (uncompress) → `flasm.exe` (compress) → `zRecompress.exe` → `leanify.exe` |
| SQLite | `sqlite3.exe` |
| TAR | `leanify.exe` |
| Tencent QQ | `leanify.exe` |
| TGA | `magick.exe` |
| TIFF and DNG | `jhead.exe` → `magick.exe` → `jpegoptim.exe` → `jpegtran.exe` → `mozjpegtran.exe` → `tinydng-cli.exe` |
| WAV | `shntool.exe` (strip) → `shntool.exe` (trim) |
| XML | `leanify.exe` → `minify.exe` |
| WEBP | `pingo.exe` → `cwebp.exe` |
| ZIP | `leanify.exe` → `ECT.exe` → `advzip.exe` → `deflopt.exe` → `defluff.exe` → `deflopt.exe` |
| 7Z | `m7zrepacker.exe` |
| Miscellaneous images | `magick.exe` |

The direct CLI adapters for `defluff.bat`, `jsmin.bat`, `libdeflate.bat`, and `sqlite.bat` invoke `defluff.exe`, `jsmin.exe`, `gzip.exe`, and `sqlite3.exe` respectively. No command interpreter is launched. The installed `7z.exe` and `rehuff.exe` are not called directly by the current pipeline; `7z.exe` may be used internally by `m7zrepacker.exe`.

Common conditional gates include CSS/HTML/JS cleanup options, EXE UPX and PETrim options, metadata and lossy-image options, PDF profile and layered-file checks, PNG animation and nine-patch checks, ZIP recursion, and optimization level. Consult the individual `if` statements for exact gates and flags.
