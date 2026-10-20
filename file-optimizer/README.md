# FileOptimizer

FileOptimizer reduces file sizes with format-specific command-line tools. Add files or folders, then choose **Optimize all**. A file is replaced only when the processed copy is smaller. The original is copied to the Recycle Bin by default.

See the [user guide](docs/usage.md) for file handling, backups, settings, and parallel processing.

## Portable layout

Keep these items together when running the application:

```text
FileOptimizer.exe
FileOptimizer.ini          (created when settings are saved)
lang/
  ko.ini
plugin/
  <command-line programs and their required DLLs>
```

The `plugin` folder is supplied separately. If a tool is missing, its processing step is skipped. The application uses built-in English text and reads `lang/ko.ini` for Korean. Settings are stored beside `FileOptimizer.exe` in `FileOptimizer.ini`.

## Command-line programs

The versions below were checked from an installed x64 tool set on 2026-10-20. “Not reported” means the installed executable did not provide a reliable version. Some programs apply only to particular file types or settings.

| Program (`plugin` file) | Installed version |
| --- | --- |
| [7-Zip](https://7-zip.org) (`7z.exe`) | 16.04 |
| [AdvanceCOMP](https://github.com/amadvance/advancecomp) (`advdef.exe`, `advmng.exe`, `advpng.exe`, `advzip.exe`) | 2.5 |
| [APNG Optimizer](https://sourceforge.net/projects/apng/) (`apngopt.exe`) | 1.4 |
| [Best CFBF Optimizer](https://papas-best.com/cfbf_en) (`bestcfbf.exe`) | 2019.11.01 |
| [jpegli](https://github.com/google/jpegli) (`cjpegli.exe`) | Not reported |
| [Coherent PDF Command Line Tools](https://www.coherentpdf.com/) (`cpdf.exe`) | 2.8.1 |
| [CSSTidy](https://csstidy.sourceforge.net/) (`csstidy.exe`) | 1.3 |
| [libwebp](https://developers.google.com/speed/webp) (`cwebp.exe`) | 1.6.0 |
| [DeflOpt](http://www.walbeehm.com/download/) (`DeflOpt.exe`) | 2.07 |
| [defluff](https://j-o.users.sourceforge.net/) (`defluff.exe`) | 0.3.2 |
| [Document Press](https://encode.su/threads/336-Document-Press-6-01) (`docprc.exe`) | 6.01 |
| [Efficient Compression Tool](https://github.com/fhanau/Efficient-Compression-Tool) (`ECT.exe`) | 0.9.5 |
| [FFmpeg](https://ffmpeg.org/) (`ffmpeg.exe`) | 8.0 |
| [FLAC](https://xiph.org/flac/) (`flac.exe`) | 1.5.0 |
| [FLACOut](https://advsys.net/ken/utils.htm) (`flacout.exe`) | 2014-07-03 build |
| [Flasm](https://flasm.sourceforge.net/) (`flasm.exe`) | 1.62 |
| [Gifsicle](https://www.lcdf.org/gifsicle/) (`gifsicle.exe`) | 1.95 |
| [Ghostscript](https://www.ghostscript.com/) (`gswin64c.exe`) | 10.05.1 |
| [Guetzli CUDA/OpenCL](https://github.com/doterax/guetzli-cuda-opencl) (`guetzli.exe`) | 2.1.5 |
| [GNU Gzip](https://www.gnu.org/software/gzip/) (`gzip.exe`) | 1.7 |
| [ImageWorsener](https://entropymine.com/imageworsener/) (`imagew.exe`) | 1.3.5 |
| [jhead](https://www.sentex.net/~mwandel/jhead/) (`jhead.exe`) | 3.04 |
| [jpeg-archive](https://github.com/danielgtaylor/jpeg-archive) (`jpeg-recompress.exe`) | 2.2.0 |
| [jpegoptim](https://github.com/tjko/jpegoptim) (`jpegoptim.exe`) | 1.5.5 |
| [jpegtran](https://jpegclub.org/jpegtran/) (`jpegtran.exe`) | Not reported |
| [JSMin](https://www.crockford.com/jsmin.html) (`jsmin.exe`) | Not reported |
| [Leanify](https://github.com/JayXon/Leanify) (`Leanify.exe`) | 0.4.3 |
| [m7zRepacker](https://encode.su/threads/1201-m7zRepacker) (`m7zRepacker.exe`) | 1.0.32.319 |
| [ImageMagick](https://imagemagick.org/) (`magick.exe`) | 7.1.2-0 |
| [Minify](https://github.com/tdewolff/minify) (`minify.exe`) | 2.20.19 |
| [mkclean](https://www.matroska.org/downloads/mkclean.html) (`mkclean.exe`) | 0.9.0 |
| [MozJPEG](https://github.com/mozilla/mozjpeg) (`mozjpegtran.exe`) | 4.1.5 |
| [MP3packer](http://omion.dyndns.org/mp3packer/mp3packer.html) (`mp3packer.exe`) | 2.04-268 |
| [mp4v2](https://github.com/TechSmith/mp4v2) (`mp4file.exe`) | 2.0.0 |
| [MuPDF](https://mupdf.com/) (`mutool.exe`) | 1.26.2 |
| [OptiVorbis](https://github.com/OptiVorbis/OptiVorbis) (`optivorbis.exe`) | 0.3.0 |
| [OxiPNG](https://github.com/oxipng/oxipng) (`oxipng.exe`) | 9.1.5 |
| [PETrim](https://bitsum.com/pesuite/) (`PETrim.exe`) | 4.0.0.0 beta |
| [pingo](http://css-ig.net/pingo) (`pingo.exe`) | Not reported |
| [PngOptimizer](https://psydk.org/PngOptimizer) (`PngOptimizer.exe`) | 2.7 |
| [PNGOUT](https://advsys.net/ken/utils.htm) (`pngout.exe`) | 2015-02-13 build |
| [pngquant](https://pngquant.org/) (`pngquant.exe`) | 2.17.0 |
| [pngrewrite](https://entropymine.com/jason/pngrewrite/) (`pngrewrite.exe`) | 1.4.0 |
| [pngwolf-zopfli](https://github.com/jibsen/pngwolf-zopfli) (`pngwolf.exe`) | 1.1.2 |
| [qpdf](https://github.com/qpdf/qpdf) (`qpdf.exe`) | 12.2.0 |
| [rehuff](https://wiki.xiph.org/Rehuff) (`rehuff.exe`, `rehuff_theora.exe`) | Not reported |
| [shntool](http://shnutils.freeshell.org/shntool/) (`shntool.exe`) | 3.0.10 |
| [SQLite](https://sqlite.org/) (`sqlite3.exe`) | 3.50.4 |
| [GNU Binutils](https://www.gnu.org/software/binutils/) (`strip.exe`) | 2.36.1 |
| [HTML Tidy](https://www.html-tidy.org/) (`tidy.exe`) | 5.9.14 |
| [TinyDNG](https://tinydng.com/) (`tinydng-cli.exe`) | 0.1.1 |
| [TruePNG](http://x128.ho.ua/pngutils.html) (`TruePNG.exe`) | 0.6.2.5 |
| [UPX](https://upx.github.io/) (`upx.exe`) | 5.0.2 |
| [zRecompress](http://nikkhokkho.sourceforge.net/static.php?page=zRecompress) (`zRecompress.exe`) | R2.12 |

버튼 아이콘은 [famfamfam-silk](https://github.com/legacy-icons/famfamfam-silk)의 것을 사용하고 있습니다.
