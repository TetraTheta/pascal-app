unit optimizer_service;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, IniFiles, optimizer_configuration;

type
  TFileState = (fsPending, fsRunning, fsDone, fsSkipped, fsFailed, fsCancelled, fsCached);

  TFileResult = record
    FileName: string;
    DetectedExtension: string;
    OriginalSize: Int64;
    OptimizedSize: Int64;
    State: TFileState;
    Detail: string;
    PluginRuns: Integer;
    StartOrder: QWord;
    StartedTick: QWord;
    ElapsedMilliseconds: QWord;
    LastPluginError: string;
  end;

  TOptimizerService = class;

  { TOptimizerWorker processes one file at a time; a file's plugin chain stays ordered. }
  TOptimizerWorker = class(TThread)
  private
    FService: TOptimizerService;
  protected
    procedure Execute; override;
  public
    constructor Create(AService: TOptimizerService);
  end;

  TOptimizerService = class
  private
    FConfiguration: TOptimizerConfiguration;
    FLock: SyncObjs.TCriticalSection;
    FItems: array of TFileResult;
    FWorkers: array of TOptimizerWorker;
    FNextIndex: Integer;
    FCancelled: Boolean;
    FPluginDirectory: string;
    FCache: TMemIniFile;
    FStartSequence: QWord;
    function Cached(const APath: string): Boolean;
    function CacheSignature(const APath: string): string;
    function ClaimNext: Integer;
    function CommitFile(const AOriginal, AWorkingFile: string; out AError: string): Boolean;
    function CopyFileData(const ASource, ADestination: string): Boolean;
    function FileSizeOrZero(const APath: string): Int64;
    function IsCancelled: Boolean;
    function RunBatchPlugin(const ATool, AInputFile, AOutputFile: string): Integer;
    function RunPlugin(const AIndex: Integer; const AStatus, ACommand, AInputFile, AOutputFile: string; const AErrorMin, AErrorMax: Integer): Boolean;
    function RunRedirectedProcess(const AExecutable, AArguments, AInputFile, AOutputFile: string; const AAppendOutput: Boolean = False): Integer;
    function RunTool(const AIndex: Integer; const AStatus, ATool, AArguments, AWorkingFile: string; const AInPlace: Boolean; const AErrorMin, AErrorMax: Integer): Boolean;
    procedure CleanCache;
    procedure ProcessItem(const AIndex: Integer);
    procedure RunFormatPlugins(const AIndex: Integer; const AWorkingFile: string);
    procedure SetResult(const AIndex: Integer; const AState: TFileState; const ASize: Int64; const ADetail: string);
    procedure UpdateCache(const APath: string);
    procedure WritePluginLog(const ACommand, AStatus: string; const AExitCode: Integer; const AOriginalSize, AOptimizedSize: Int64; const AStartedAt: TDateTime);
  public
    constructor Create(AConfiguration: TOptimizerConfiguration; const AExecutablePath: string);
    destructor Destroy; override;
    function Count: Integer;
    function Finished: Boolean;
    function Item(const AIndex: Integer): TFileResult;
    function LatestStartedIndex: Integer;
    procedure AddFile(const AFileName: string);
    procedure Clear;
    procedure RefreshSizes;
    procedure RemoveDone;
    procedure RemoveItem(const AIndex: Integer);
    procedure SortByColumn(const AColumn: Integer; const ADescending: Boolean);
    procedure Start;
    procedure Stop;
    property PluginDirectory: string read FPluginDirectory;
  end;

implementation

uses
  Math, StrUtils, Windows, ShellApi;

function ReplaceFileW(AReplaced, AReplacement, ABackup: PWideChar; AFlags: DWORD; AExclude, AReserved: Pointer): BOOL;
  stdcall; external 'kernel32.dll' name 'ReplaceFileW';

const
  KS_EXTENSION_7Z = ' .7z .lzma ';
  KS_EXTENSION_AVIF = ' .avif .heif .heifs .heic .heics .avci .avcs .avif .avifs ';
  KS_EXTENSION_BMP = ' .bmp .dib ';
  KS_EXTENSION_CSS = ' .css ';
  KS_EXTENSION_DLL = ' .dll .bpl .cpl .drv .icl .lzl .ocx .rll .sys .vbx ';
  KS_EXTENSION_EXE = ' .exe .scr ';
  KS_EXTENSION_FLAC = ' .flac ';
  KS_EXTENSION_GIF = ' .gif ';
  KS_EXTENSION_GZ = ' .gz .deb .ipk .tgz .svgz .vlt ';
  KS_EXTENSION_HTML = ' .htm .html .mht .mhtml .xhtml .xml .sgml .svg ';
  KS_EXTENSION_ICO = ' .ico .cur .spl ';
  KS_EXTENSION_JP2 = ' .jp2 .j2c .j2k ';
  KS_EXTENSION_JPG = ' .jfi .jif .jfif .jng .jpe .jpg .jpeg .thm .mpo .jps ';
  KS_EXTENSION_JS = ' .js .json ';
  KS_EXTENSION_JXL = ' .jxl ';
  KS_EXTENSION_LUA = ' .lua .luac ';
  KS_EXTENSION_MIME = ' .mht .mhtml .eml .emlx .msg .mbx .vcf .vcard ';
  KS_EXTENSION_MISC = ' .aai .art .avs .bpg .cin .cmyk .cmyka .dds .dpx .epdf .fax .fits .fpx .gray .hdr .hrz .inline .jpc .jpt .mono .mif .miff .mpc .mpr .msl .mtv .mvg .otb .p7 .palm .pcd .pcds .pcl .pcls .pdb .pbm .pfs .pfm .pgm .picon .pic .pict .pnm .ppm .psb .psd .ptif .ptiff .rfg .rgb .rgba .sgi .sun .uyvy .vicar .viff .wbmp .x .xbm .xpm .xwd .ycbr .ycbra .yub ';
  KS_EXTENSION_MKV = ' .mkv .mka .mks .mk3d .webm .weba ';
  KS_EXTENSION_MNG = ' .mng ';
  KS_EXTENSION_MP3 = ' .mp3 ';
  KS_EXTENSION_MP4 = ' .mp4 .3gp .3gg .3g2 .m4a .m4b .m4p .m4r .m4v .acc .avi .mpg .mpeg .vob .flv .wmv .wma .rv .ra .rm .rmvb .ram .smil .qt .mov ';
  KS_EXTENSION_OBJ = ' .obj .o .lib .a ';
  KS_EXTENSION_OGG = ' .ogg .oga .ogx .ogm .spx .opus ';
  KS_EXTENSION_OGV = ' .ogg .ogv .ogx ';
  KS_EXTENSION_OLE = ' .ac .adp .apr .art .chm .chi .chq .chs .chw .db .doc .dot .fla .fpx .its .lit .max .mce .mdb .mdt .mic .mix .mpd .mpp .mpt .msc .msi .msg .msp .mst .mtw .mzz .ole .ole2 .one .opt .ost .pps .ppt .pub .puz .rfa .rft .rte .rvt .sldasm .sldprt .slddrw .sou .spo stickynotes.snt thumbs.db .vsd .vst .vss .wiz .wps .xl .xla .xlc .xlm .xls .xlw .xsf .xsn ';
  KS_EXTENSION_PCX = ' .dcx .pcc .pcx ';
  KS_EXTENSION_PDF = ' .epdf .pdf .fdf .ai ';
  KS_EXTENSION_PNG = ' .apng .ico .png .pns ';
  KS_EXTENSION_SQLITE = ' .sqlite .sqlite3 .sqlite2 .db ';
  KS_EXTENSION_SWF = ' .swf ';
  KS_EXTENSION_TAR = ' .tar .cbt ';
  KS_EXTENSION_TENCENTQQ = ' .gft .rdb ';
  KS_EXTENSION_TGA = ' .tga .icb .vda .vst ';
  KS_EXTENSION_TIFF = ' .fax .tif .tiff .ptif .ptiff .dng ';
  KS_EXTENSION_WAV = ' .wav ';
  KS_EXTENSION_WEBP = ' .webp ';
  KS_EXTENSION_XML = ' .xml .fb2 .fxg .kml .xsl .xslt .xhtml ';
  KS_EXTENSION_ZIP = ' .air .apk .appx .bar .bsz .cbz .cdr .cdt .csl .des .docm .docx .dotx .dotm .dwf .dwfx .ear .easm .eprt .epub .fxg .gallery .gallerycollection .galleryitem .grs .ink .ipsw .itz .ipa .ita .jar .kmz .ksf .kmz .lxf .mdz .miz .mmip .mvz .mpp .msz .nar .nbk .notebook .ora .odb .odf .odg .odp .ods .odt .oex .osk .oxps .pk3 .ppam .potm .potx .ppsm .ppsx .pptm .pptx .pub .qwk .r2skin .rdb .rmskin .s3z .sldm .sldx .stz .swc .vdx .vtx .vsx .wal .war .wba .wmz .wsz .xap .xlam .xlsb .xlsm .xlsx .xltm .xltx .xnk .xmz .xpi .xps .z01 .z02 .z03 .z04 .z05 .z06 .z07 .z08 .z09 .z10 .zip .zx01 .zx02 .zx03 .zx04 .zx05 .zx05 .zx06 .zx07 .zx08 .zx09 .zx10 .zipx ';

type
  TOriginalOptions = record
    acCSSTemplate, acJSAdditionalExtensions, acPDFProfile: string;
    bBMPCopyMetadata, bCSSEnableTidy, bDebug, bEXEDisablePETrim, bEXEEnableUPX, bGIFAllowLossy, bGIFCopyMetadata, bGZCopyMetadata,
      bHTMLEnableTidy, bJPEGAllowLossy, bJPEGCopyMetadata, bJPEGUseArithmeticEncoding, bJSEnableJSMin, bLUAEnableLeanify,
      bMiscCopyMetadata, bMiscDisable, bMP3CopyMetadata, bMP4CopyMetadata, bPCXCopyMetadata, bPDFSkipLayered, bPNGAllowLossy,
      bPNGCopyMetadata, bTGACopyMetadata, bTIFFCopyMetadata, bWAVCopyMetadata, bWAVStripSilence, bWEBPAllowLossy,
      bXMLEnableLeanify, bZIPCopyMetadata, bZIPRecurse: Boolean;
    iLeanifyIterations, iLevel, iPDFCustomDPI, iPNGWolfIterations: Integer;
  end;

function GetFileSize(const APath: string): Int64;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    Result := Stream.Size;
  finally
    Stream.Free;
  end;
end;

function NewTempPath(const ADirectory: string): string;
var
  Identifier: TGUID;
begin
  CreateGUID(Identifier);
  Result := IncludeTrailingPathDelimiter(ADirectory) + 'FileOptimizer_' + Copy(GUIDToString(Identifier), 2, 36);
end;

function StringReplaceAll(const AValue, AOld, ANew: string): string;
begin
  Result := StringReplace(AValue, AOld, ANew, [rfReplaceAll]);
end;

function MatchesMask(const APath, AMask: string): Boolean;
var
  Index: Integer;
  Parts: TStringList;
begin
  Result := False;
  if AMask = '' then
    Exit;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    Parts.DelimitedText := AMask;
    for Index := 0 to Parts.Count - 1 do
      if (Trim(Parts[Index]) <> '') and (Pos(UpperCase(Trim(Parts[Index])), UpperCase(APath)) > 0) then
        Exit(True);
  finally
    Parts.Free;
  end;
end;

function GetExtensionByContent(const APath, AJSAdditional: string; const AUseName: Boolean = False): string;
const
  KnownExtensions = KS_EXTENSION_AVIF + KS_EXTENSION_BMP + KS_EXTENSION_CSS + KS_EXTENSION_DLL + KS_EXTENSION_EXE +
                    KS_EXTENSION_FLAC + KS_EXTENSION_GIF + KS_EXTENSION_GZ + KS_EXTENSION_HTML + KS_EXTENSION_ICO +
                    KS_EXTENSION_JPG + KS_EXTENSION_JP2 + KS_EXTENSION_JS + KS_EXTENSION_JXL + KS_EXTENSION_LUA +
                    KS_EXTENSION_MIME + KS_EXTENSION_MKV + KS_EXTENSION_MNG + KS_EXTENSION_MP3 + KS_EXTENSION_MP4 +
                    KS_EXTENSION_OBJ + KS_EXTENSION_OGG + KS_EXTENSION_OGV + KS_EXTENSION_OLE + KS_EXTENSION_PCX +
                    KS_EXTENSION_PDF + KS_EXTENSION_PNG + KS_EXTENSION_SQLITE + KS_EXTENSION_SWF + KS_EXTENSION_TAR +
                    KS_EXTENSION_TENCENTQQ + KS_EXTENSION_TGA + KS_EXTENSION_TIFF + KS_EXTENSION_WAV +
                    KS_EXTENSION_WEBP + KS_EXTENSION_XML + KS_EXTENSION_ZIP + KS_EXTENSION_7Z + KS_EXTENSION_MISC;
var
  Buffer, Tail: AnsiString;
  Extension, GroupExtensions: string;
  Size: Int64;
  Stream: TFileStream;
begin
  Extension := LowerCase(ExtractFileExt(APath));
  Result := '';
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    Size := Stream.Size;
    SetLength(Buffer, Min(Size, 512));
    if Length(Buffer) = 0 then
      Exit;
    Stream.ReadBuffer(Buffer[1], Length(Buffer));
    if Size >= 512 then
    begin
      SetLength(Tail, 512);
      Stream.Position := Size - 512;
      Stream.ReadBuffer(Tail[1], 512);
    end;
  finally
    Stream.Free;
  end;
  if Copy(Buffer, 5, 4) = 'ftyp' then
  begin
    if (Copy(Buffer, 9, 4) = 'avif') or (Copy(Buffer, 9, 4) = 'avis') then
      Result := '.avif'
    else if (Copy(Buffer, 9, 4) = 'heic') or (Copy(Buffer, 9, 4) = 'heix') or (Copy(Buffer, 9, 4) = 'mif1') then
      Result := '.heic'
    else
      Result := '.mp4';
  end
  else if (Copy(Buffer, 1, 2) = 'BM') or (Copy(Buffer, 1, 2) = 'BA') or (Copy(Buffer, 1, 2) = 'CI') or (Copy(Buffer, 1, 2) = 'CP') or (Copy(Buffer, 1, 2) = 'IC') or (Copy(Buffer, 1, 2) = 'PT') then
    Result := '.bmp'
  else if (Copy(Buffer, 1, 2) = 'MZ') or (Copy(Buffer, 1, 2) = 'ZM') then
    Result := '.dll'
  else if Copy(Buffer, 1, 4) = 'fLaC' then
    Result := '.flac'
  else if Copy(Buffer, 1, 4) = 'GIF8' then
    Result := '.gif'
  else if Copy(Buffer, 1, 3) = #$1F#$8B#$08 then
    Result := '.gz'
  else if Copy(Buffer, 1, 4) = #0#0#1#0 then
    Result := '.ico'
  else if Copy(Buffer, 5, 2) = 'jP' then
    Result := '.jp2'
  else if Copy(Buffer, 1, 3) = #$FF#$D8#$FF then
    Result := '.jpg'
  else if Copy(Buffer, 1, 12) = #0#0#0#$0C'JXL '#$0D#$0A#$87#$0A then
    Result := '.jxl'
  else if (Copy(Buffer, 1, 4) = #$1A#$45#$DF#$A3) or (Copy(Buffer, 1, 4) = '.RTS') then
    Result := '.mkv'
  else if Copy(Buffer, 1, 8) = #$8A'MNG'#$0D#$0A#$1A#$0A then
    Result := '.mng'
  else if Copy(Buffer, 1, 3) = 'ID3' then
    Result := '.mp3'
  else if (Copy(Buffer, 1, 2) = #$4C#$01) or (Buffer[1] = #$80) then
    Result := '.obj'
  else if Copy(Buffer, 1, 4) = 'OggS' then
    Result := '.ogg'
  else if (Copy(Buffer, 1, 8) = #$D0#$CF#$11#$E0#$A1#$B1#$1A#$E1) or (Copy(Buffer, 1, 8) = #$0E#$11#$FC#$0D#$D0#$CF#$11#$0E) then
    Result := '.ole'
  else if (Length(Buffer) >= 75) and (Buffer[1] = #10) and (Buffer[3] = #1) and (Buffer[65] = #0) and (Buffer[75] = #0) then
    Result := '.pcx'
  else if Copy(Buffer, 1, 5) = '%PDF-' then
    Result := '.pdf'
  else if Copy(Buffer, 1, 8) = #$89'PNG'#$0D#$0A#$1A#$0A then
    Result := '.png'
  else if Copy(Buffer, 1, 15) = 'SQLite format 3' then
    Result := '.sqlite'
  else if Copy(Buffer, 1, 3) = 'FWS' then
    Result := '.swf'
  else if Copy(Buffer, 1, 3) = 'CWS' then
    Result := '.swf'
  else if Copy(Buffer, 1, 3) = 'ZWS' then
    Result := '.swf'
  else if Copy(Buffer, 258, 5) = 'ustar' then
    Result := '.tar'
  else if (Length(Tail) >= 18) and (Copy(Tail, 495, 10) = 'TRUEVISION') then
    Result := '.tga'
  else if (Copy(Buffer, 1, 2) = #$0C#$ED) or (Copy(Buffer, 1, 3) = 'I I') or (Copy(Buffer, 1, 4) = 'II*'#0) or (Copy(Buffer, 1, 4) = 'MM'#0'+') then
    Result := '.tif'
  else if Copy(Buffer, 1, 4) = 'RIFF' then
  begin
    if Copy(Buffer, 9, 4) = 'WEBP' then
      Result := '.webp'
    else if Copy(Buffer, 9, 4) = 'WAVE' then
      Result := '.wav';
  end
  else if Copy(Buffer, 1, 4) = 'PK'#$03#$04 then
    Result := '.zip'
  else if Copy(Buffer, 1, 4) = 'MSCF' then
    Result := '.cab'
  else if Copy(Buffer, 1, 6) = '7z'#$BC#$AF#$27#$1C then
    Result := '.7z';
  if AUseName then
    Exit;
  if Result = '' then
  begin
    if (Pos(' ' + Extension + ' ', KnownExtensions) > 0) or (Pos(' ' + Extension + ' ', ' ' + StringReplace(LowerCase(AJSAdditional), ',', ' ', [rfReplaceAll]) + ' ') > 0) then
      Result := Extension;
    Exit;
  end;
  GroupExtensions := '';
  case Result of
    '.7z': GroupExtensions := KS_EXTENSION_7Z;
    '.avif': GroupExtensions := KS_EXTENSION_AVIF;
    '.bmp': GroupExtensions := KS_EXTENSION_BMP;
    '.dll': GroupExtensions := KS_EXTENSION_DLL + KS_EXTENSION_EXE;
    '.flac': GroupExtensions := KS_EXTENSION_FLAC;
    '.gif': GroupExtensions := KS_EXTENSION_GIF;
    '.gz': GroupExtensions := KS_EXTENSION_GZ;
    '.heic': GroupExtensions := KS_EXTENSION_AVIF;
    '.ico': GroupExtensions := KS_EXTENSION_ICO;
    '.jp2': GroupExtensions := KS_EXTENSION_JP2;
    '.jpg': GroupExtensions := KS_EXTENSION_JPG;
    '.jxl': GroupExtensions := KS_EXTENSION_JXL;
    '.mkv': GroupExtensions := KS_EXTENSION_MKV;
    '.mng': GroupExtensions := KS_EXTENSION_MNG;
    '.mp3': GroupExtensions := KS_EXTENSION_MP3;
    '.mp4': GroupExtensions := KS_EXTENSION_MP4;
    '.obj': GroupExtensions := KS_EXTENSION_OBJ;
    '.ogg': GroupExtensions := KS_EXTENSION_OGG + KS_EXTENSION_OGV;
    '.ole': GroupExtensions := KS_EXTENSION_OLE;
    '.pcx': GroupExtensions := KS_EXTENSION_PCX;
    '.pdf': GroupExtensions := KS_EXTENSION_PDF;
    '.png': GroupExtensions := KS_EXTENSION_PNG;
    '.sqlite': GroupExtensions := KS_EXTENSION_SQLITE;
    '.swf': GroupExtensions := KS_EXTENSION_SWF;
    '.tar': GroupExtensions := KS_EXTENSION_TAR;
    '.tga': GroupExtensions := KS_EXTENSION_TGA;
    '.tif': GroupExtensions := KS_EXTENSION_TIFF;
    '.wav': GroupExtensions := KS_EXTENSION_WAV;
    '.webp': GroupExtensions := KS_EXTENSION_WEBP;
    '.zip': GroupExtensions := KS_EXTENSION_ZIP;
  end;
  if Pos(' ' + Extension + ' ', GroupExtensions) > 0 then
    Result := Extension;
end;

function IsAPNG(const APath: string): Boolean;
var
  ChunkHeader: array[0..7] of Byte;
  ChunkLength: QWord;
  Signature: array[0..7] of Byte;
  Stream: TFileStream;
begin
  Result := False;
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    if Stream.Read(Signature, SizeOf(Signature)) <> SizeOf(Signature) then
      Exit;
    if (Signature[0] <> $89) or (Signature[1] <> Ord('P')) then
      Exit;
    while Stream.Position + 12 <= Stream.Size do
    begin
      Stream.ReadBuffer(ChunkHeader, SizeOf(ChunkHeader));
      ChunkLength := QWord(ChunkHeader[0]) shl 24 or QWord(ChunkHeader[1]) shl 16 or QWord(ChunkHeader[2]) shl 8 or QWord(ChunkHeader[3]);
      if (ChunkHeader[4] = Ord('a')) and (ChunkHeader[5] = Ord('c')) and (ChunkHeader[6] = Ord('T')) and (ChunkHeader[7] = Ord('L')) then
        Exit(True);
      if ChunkLength > QWord(Stream.Size - Stream.Position - 4) then
        Exit;
      Stream.Position := Stream.Position + ChunkLength + 4;
    end;
  finally
    Stream.Free;
  end;
end;

function IsEXESFX(const APath: string): Boolean;
var
  Buffer: AnsiString;
  Stream: TFileStream;
begin
  Result := False;
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Buffer, Min(Stream.Size, 1024 * 1024));
    if Length(Buffer) < 2 then
      Exit;
    Stream.ReadBuffer(Buffer[1], Length(Buffer));
  finally
    Stream.Free;
  end;
  if Copy(Buffer, 1, 2) <> 'MZ' then
    Exit;
  Result := (Pos('Inno Setup', Buffer) > 0) or (Pos('InstallShield', Buffer) > 0) or (Pos('Nullsoft Install System', Buffer) > 0) or
            (Pos('RTPatch', Buffer) > 0) or (Pos('Rar!'#$1A#$07, Buffer) > 0) or (Pos('PK'#$03#$04, Buffer) > 0) or
            (Pos('7z'#$BC#$AF#$27#$1C, Buffer) > 0) or (Pos('MSCF', Buffer) > 0);
end;

function IsJPEGCMYK(const APath: string): Boolean;
var
  Buffer: array[0..524287] of Byte;
  Count, Position, SegmentLength: Longint;
  Marker: Byte;
  Stream: TFileStream;
begin
  Result := False;
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    Count := Stream.Read(Buffer, SizeOf(Buffer));
  finally
    Stream.Free;
  end;
  if (Count < 4) or (Buffer[0] <> $FF) or (Buffer[1] <> $D8) then
    Exit;
  Position := 2;
  while Position + 10 <= Count do
  begin
    if Buffer[Position] <> $FF then
      Exit;
    Marker := Buffer[Position + 1];
    if Marker = $FF then
    begin
      Inc(Position);
      Continue;
    end;
    if (Marker >= $C0) and (Marker <= $CF) and not (Marker in [$C4, $C8, $CC]) then
      Exit(Buffer[Position + 9] = 4);
    if Marker in [$DA, $D9] then
      Exit;
    SegmentLength := Buffer[Position + 2] shl 8 or Buffer[Position + 3];
    if SegmentLength < 2 then
      Exit;
    Inc(Position, SegmentLength + 2);
  end;
end;

function IsPDFLayered(const APath: string): Boolean;
var
  Buffer: AnsiString;
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Buffer, Min(Stream.Size, 512 * 1024));
    if Length(Buffer) > 0 then
      Stream.ReadBuffer(Buffer[1], Length(Buffer));
  finally
    Stream.Free;
  end;
  Result := Pos('<< /Type /OCG /Name', Buffer) > 0;
end;

function GetSystemThreadCount: Integer;
var
  SystemInfo: TSystemInfo;
begin
  GetSystemInfo(SystemInfo);
  Result := SystemInfo.dwNumberOfProcessors;
end;

function MoveCopyToRecycleBin(const ASource, ADestination: string): Boolean;
var
  Operation: TSHFileOpStructW;
  SourceList: UnicodeString;
begin
  Result := False;
  if not Windows.CopyFileW(PWideChar(UnicodeString(ASource)), PWideChar(UnicodeString(ADestination)), False) then
    Exit;
  FillChar(Operation, SizeOf(Operation), 0);
  SourceList := UnicodeString(ADestination) + #0#0;
  Operation.wFunc := FO_DELETE;
  Operation.pFrom := PWideChar(SourceList);
  Operation.fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_SILENT;
  Result := (SHFileOperationW(@Operation) = 0) and not Operation.fAnyOperationsAborted;
  if not Result then
    SysUtils.DeleteFile(ADestination);
end;

constructor TOptimizerWorker.Create(AService: TOptimizerService);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FService := AService;
end;

procedure TOptimizerWorker.Execute;
var
  Index: Integer;
begin
  repeat
    Index := FService.ClaimNext;
    if Index >= 0 then
      try
        FService.ProcessItem(Index);
      except
        on E: Exception do
          FService.SetResult(Index, fsFailed, FService.Item(Index).OriginalSize, E.Message);
      end;
  until Index < 0;
end;

constructor TOptimizerService.Create(AConfiguration: TOptimizerConfiguration; const AExecutablePath: string);
begin
  inherited Create;
  FConfiguration := AConfiguration;
  FLock := SyncObjs.TCriticalSection.Create;
  FPluginDirectory := IncludeTrailingPathDelimiter(ExtractFilePath(AExecutablePath)) + 'plugin';
  if FConfiguration.GetBoolean('General', 'EnableCache') then
    FCache := TMemIniFile.Create(ChangeFileExt(FConfiguration.Path, '.Cache.ini'));
end;

destructor TOptimizerService.Destroy;
begin
  Stop;
  if Assigned(FCache) and FileExists(ChangeFileExt(FConfiguration.Path, '.Cache.ini')) and (GetFileSize(ChangeFileExt(FConfiguration.Path, '.Cache.ini')) > 2 * 1024 * 1024) then
  begin
    CleanCache;
    FCache.UpdateFile;
  end;
  FCache.Free;
  FLock.Free;
  inherited Destroy;
end;

function CacheKey(const APath: string): string;
var
  Character: Char;
  Hash: Cardinal;
begin
  Hash := 2166136261;
  for Character in LowerCase(APath) do
    Hash := (Hash xor Ord(Character)) * 16777619;
  Result := IntToHex(Hash, 8);
end;

function TOptimizerService.CacheSignature(const APath: string): string;
begin
  Result := LowerCase(APath) + '|' + IntToStr(FileSizeOrZero(APath)) + '|' + IntToStr(FileAge(APath));
end;

function TOptimizerService.Cached(const APath: string): Boolean;
begin
  Result := False;
  if not FConfiguration.GetBoolean('General', 'EnableCache') then
    Exit;
  FLock.Enter;
  try
    if not Assigned(FCache) then
      FCache := TMemIniFile.Create(ChangeFileExt(FConfiguration.Path, '.Cache.ini'));
    if Assigned(FCache) then
      Result := FCache.ReadString('Cache', CacheKey(APath), '') = CacheSignature(APath);
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.CleanCache;
var
  Index, Separator: Integer;
  Keys: TStringList;
  Signature: string;
begin
  Keys := TStringList.Create;
  try
    FCache.ReadSection('Cache', Keys);
    for Index := 0 to Keys.Count - 1 do
    begin
      Signature := FCache.ReadString('Cache', Keys[Index], '');
      Separator := Pos('|', Signature);
      if (Separator = 0) or not FileExists(Copy(Signature, 1, Separator - 1)) then
        FCache.DeleteKey('Cache', Keys[Index]);
    end;
  finally
    Keys.Free;
  end;
end;

procedure TOptimizerService.UpdateCache(const APath: string);
begin
  FLock.Enter;
  try
    if Assigned(FCache) then
      FCache.WriteString('Cache', CacheKey(APath), CacheSignature(APath));
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.WritePluginLog(const ACommand, AStatus: string; const AExitCode: Integer; const AOriginalSize, AOptimizedSize: Int64; const AStartedAt: TDateTime);
var
  Entry, LogPath: string;
  LogFile: TFileStream;
begin
  if FConfiguration.GetInteger('General', 'LogLevel') <= 3 then
    Exit;
  LogPath := IncludeTrailingPathDelimiter(ExtractFileDir(FPluginDirectory)) + 'FileOptimizer.log';
  Entry := 'Start: ' + DateTimeToStr(AStartedAt) + #9 + 'End: ' + DateTimeToStr(Now) + #9 + 'Level: ' + FConfiguration.GetText('General', 'Level') + #9 + 'Original: ' + IntToStr(AOriginalSize) + #9 + 'Optimized: ' + IntToStr(AOptimizedSize) + #9 + 'Errorlevel: ' + IntToStr(AExitCode) + #9 + 'Plugin: ' + AStatus + #9 + 'Commandline: ' + ACommand + LineEnding;
  FLock.Enter;
  try
    try
      if FileExists(LogPath) then
        LogFile := TFileStream.Create(LogPath, fmOpenReadWrite)
      else
        LogFile := TFileStream.Create(LogPath, fmCreate);
      try
        LogFile.Position := LogFile.Size;
        LogFile.WriteBuffer(Entry[1], Length(Entry));
      finally
        LogFile.Free;
      end;
    except
      // Logging must never turn a valid optimization into a failure.
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.AddFile(const AFileName: string);
var
  DetectedExtension: string;
  Index: Integer;
  Normalized: string;
  Size: Int64;
  IsCached: Boolean;
begin
  Normalized := ExpandFileName(AFileName);
  if not FileExists(Normalized) then
    Exit;
  try
    Size := GetFileSize(Normalized);
    if Size = 0 then
      Exit;
    DetectedExtension := GetExtensionByContent(Normalized, FConfiguration.GetText('JS', 'AdditionalExtensions'));
    if DetectedExtension = '' then
      Exit;
  except
    Exit;
  end;
  IsCached := FConfiguration.GetBoolean('General', 'EnableCache') and Cached(Normalized);
  FLock.Enter;
  try
    if not FConfiguration.GetBoolean('General', 'AllowDuplicates') then
      for Index := 0 to High(FItems) do
        if SameText(FItems[Index].FileName, Normalized) then
          Exit;
    Index := Length(FItems);
    SetLength(FItems, Index + 1);
    FItems[Index].FileName := Normalized;
    FItems[Index].DetectedExtension := DetectedExtension;
    FItems[Index].OriginalSize := Size;
    FItems[Index].OptimizedSize := FItems[Index].OriginalSize;
    FItems[Index].State := fsPending;
    FItems[Index].Detail := '';
    FItems[Index].PluginRuns := 0;
    FItems[Index].StartOrder := 0;
    FItems[Index].StartedTick := 0;
    FItems[Index].ElapsedMilliseconds := 0;
    FItems[Index].LastPluginError := '';
    if IsCached then
      FItems[Index].State := fsCached;
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.RemoveDone;
var
  Index, Kept: Integer;
begin
  if not Finished then
    Exit;
  FLock.Enter;
  try
    Kept := 0;
    for Index := 0 to High(FItems) do
      if FItems[Index].State <> fsDone then
      begin
        FItems[Kept] := FItems[Index];
        Inc(Kept);
      end;
    SetLength(FItems, Kept);
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.RefreshSizes;
var
  Index: Integer;
begin
  if not Finished then
    Exit;
  FLock.Enter;
  try
    for Index := 0 to High(FItems) do
      FItems[Index].OriginalSize := FileSizeOrZero(FItems[Index].FileName);
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.SortByColumn(const AColumn: Integer; const ADescending: Boolean);
var
  Index, SourceIndex: Integer;
  Key: string;
  Sorted: TStringList;
  SortedItems: array of TFileResult;
begin
  if not Finished then
    Exit;
  Sorted := TStringList.Create;
  try
    Sorted.CaseSensitive := False;
    Sorted.Duplicates := dupAccept;
    for Index := 0 to Count - 1 do
    begin
      case AColumn of
        0: Key := FItems[Index].FileName;
        1: Key := FItems[Index].DetectedExtension;
        2: Key := IntToStr(FItems[Index].OriginalSize);
        3: Key := IntToStr(FItems[Index].OptimizedSize);
        4: Key := IntToStr(Ord(FItems[Index].State));
      else
        Exit;
      end;
      if AColumn in [2, 3] then
        Key := StringOfChar('0', 20 - Length(Key)) + Key;
      Sorted.AddObject(Key, TObject(PtrInt(Index)));
    end;
    Sorted.Sort;
    SetLength(SortedItems, Length(FItems));
    FLock.Enter;
    try
      for Index := 0 to High(SortedItems) do
      begin
        if ADescending then
          SourceIndex := PtrInt(Sorted.Objects[High(SortedItems) - Index])
        else
          SourceIndex := PtrInt(Sorted.Objects[Index]);
        SortedItems[Index] := FItems[SourceIndex];
      end;
      FItems := SortedItems;
    finally
      FLock.Leave;
    end;
  finally
    Sorted.Free;
  end;
end;

procedure TOptimizerService.Clear;
begin
  if not Finished then
    Exit;
  FLock.Enter;
  try
    SetLength(FItems, 0);
    FNextIndex := 0;
  finally
    FLock.Leave;
  end;
end;

function TOptimizerService.Count: Integer;
begin
  FLock.Enter;
  try
    Result := Length(FItems);
  finally
    FLock.Leave;
  end;
end;

function TOptimizerService.Finished: Boolean;
var
  Index: Integer;
begin
  Result := True;
  FLock.Enter;
  try
    for Index := 0 to High(FWorkers) do
      if not FWorkers[Index].Finished then
        Exit(False);
  finally
    FLock.Leave;
  end;
end;

function TOptimizerService.Item(const AIndex: Integer): TFileResult;
begin
  FLock.Enter;
  try
    Result := FItems[AIndex];
  finally
    FLock.Leave;
  end;
end;

function TOptimizerService.LatestStartedIndex: Integer;
var
  Index: Integer;
  LatestOrder: QWord;
begin
  Result := -1;
  LatestOrder := 0;
  FLock.Enter;
  try
    for Index := 0 to High(FItems) do
      if FItems[Index].StartOrder > LatestOrder then
      begin
        LatestOrder := FItems[Index].StartOrder;
        Result := Index;
      end;
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.RemoveItem(const AIndex: Integer);
var
  Index: Integer;
begin
  if not Finished then
    Exit;
  FLock.Enter;
  try
    if (AIndex < 0) or (AIndex >= Length(FItems)) then
      Exit;
    for Index := AIndex to High(FItems) - 1 do
      FItems[Index] := FItems[Index + 1];
    SetLength(FItems, Length(FItems) - 1);
    FNextIndex := 0;
  finally
    FLock.Leave;
  end;
end;

function TOptimizerService.ClaimNext: Integer;
begin
  FLock.Enter;
  try
    Result := -1;
    if FCancelled then
      Exit;
    while (FNextIndex < Length(FItems)) and (FItems[FNextIndex].State = fsCached) do
      Inc(FNextIndex);
    if FNextIndex >= Length(FItems) then
      Exit;
    Result := FNextIndex;
    Inc(FNextIndex);
    FItems[Result].State := fsRunning;
    Inc(FStartSequence);
    FItems[Result].StartOrder := FStartSequence;
    FItems[Result].StartedTick := GetTickCount64;
  finally
    FLock.Leave;
  end;
end;

function TOptimizerService.CopyFileData(const ASource, ADestination: string): Boolean;
var
  InputFile, OutputFile: TFileStream;
begin
  Result := False;
  try
    InputFile := TFileStream.Create(ASource, fmOpenRead or fmShareDenyNone);
    try
      OutputFile := TFileStream.Create(ADestination, fmCreate);
      try
        OutputFile.CopyFrom(InputFile, InputFile.Size);
        Result := True;
      finally
        OutputFile.Free;
      end;
    finally
      InputFile.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TOptimizerService.CommitFile(const AOriginal, AWorkingFile: string; out AError: string): Boolean;
var
  Attributes: Longint;
  BackupPath, RecyclePath, StagePath: string;
  CreatedAt, AccessedAt, ModifiedAt: TFileTime;
  FileHandle: THandle;
  HasTime: Boolean;
begin
  Result := False;
  AError := '';
  StagePath := NewTempPath(ExtractFileDir(AOriginal)) + ExtractFileExt(AOriginal);
  if not CopyFileData(AWorkingFile, StagePath) then
  begin
    AError := 'Cannot stage optimized file';
    Exit;
  end;
  try
    HasTime := False;
    if FConfiguration.GetBoolean('General', 'KeepAttributes') then
    begin
      FileHandle := CreateFileW(PWideChar(UnicodeString(AOriginal)), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
      if FileHandle <> INVALID_HANDLE_VALUE then
      begin
        HasTime := GetFileTime(FileHandle, @CreatedAt, @AccessedAt, @ModifiedAt);
        CloseHandle(FileHandle);
      end;
    end;
    if not FConfiguration.GetBoolean('General', 'DoNotUseRecycleBin') then
    begin
      RecyclePath := NewTempPath(ExtractFileDir(AOriginal)) + ExtractFileExt(AOriginal);
      if not MoveCopyToRecycleBin(AOriginal, RecyclePath) then
      begin
        AError := 'Cannot back up original in Recycle Bin';
        Exit;
      end;
    end;
    if not FConfiguration.GetBoolean('General', 'DoNotCreateBackups') then
    begin
      BackupPath := AOriginal + '.bak';
      if not CopyFileData(AOriginal, BackupPath) then
      begin
        AError := 'Cannot create .bak file';
        Exit;
      end;
    end;
    Attributes := FileGetAttr(AOriginal);
    if Attributes <> -1 then
      FileSetAttr(AOriginal, faArchive);
    if ReplaceFileW(PWideChar(UnicodeString(AOriginal)), PWideChar(UnicodeString(StagePath)), nil, 0, nil, nil) then
    begin
      Result := True;
      if HasTime then
      begin
        FileHandle := CreateFileW(PWideChar(UnicodeString(AOriginal)), FILE_WRITE_ATTRIBUTES, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
        if FileHandle <> INVALID_HANDLE_VALUE then
        begin
          SetFileTime(FileHandle, @CreatedAt, @AccessedAt, @ModifiedAt);
          CloseHandle(FileHandle);
        end;
      end;
      if FConfiguration.GetBoolean('General', 'KeepAttributes') and (Attributes <> -1) then
        FileSetAttr(AOriginal, Attributes);
    end
    else
    begin
      AError := 'Cannot replace original';
      if Attributes <> -1 then
        FileSetAttr(AOriginal, Attributes);
    end;
  finally
    SysUtils.DeleteFile(StagePath);
  end;
end;

function TOptimizerService.FileSizeOrZero(const APath: string): Int64;
begin
  Result := 0;
  if FileExists(APath) then
    Result := GetFileSize(APath);
end;

function TOptimizerService.IsCancelled: Boolean;
begin
  FLock.Enter;
  try
    Result := FCancelled;
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.SetResult(const AIndex: Integer; const AState: TFileState; const ASize: Int64; const ADetail: string);
begin
  FLock.Enter;
  try
    FItems[AIndex].State := AState;
    FItems[AIndex].OptimizedSize := ASize;
    FItems[AIndex].Detail := ADetail;
    if (AState <> fsRunning) and (FItems[AIndex].StartedTick > 0) then
      FItems[AIndex].ElapsedMilliseconds := GetTickCount64 - FItems[AIndex].StartedTick;
  finally
    FLock.Leave;
  end;
end;

procedure TOptimizerService.Start;
var
  Index, WorkerCount: Integer;
begin
  if not Finished then
    Exit;
  for Index := 0 to High(FWorkers) do
    FWorkers[Index].Free;
  SetLength(FWorkers, 0);
  FLock.Enter;
  try
    FCancelled := False;
    FNextIndex := 0;
    for Index := 0 to High(FItems) do
    begin
      FItems[Index].State := fsPending;
      FItems[Index].OptimizedSize := FItems[Index].OriginalSize;
      FItems[Index].Detail := '';
      FItems[Index].PluginRuns := 0;
      FItems[Index].LastPluginError := '';
    end;
  finally
    FLock.Leave;
  end;
  if Assigned(FCache) then
    FCache.UpdateFile;
  FCache.Free;
  FCache := nil;
  if FConfiguration.GetBoolean('General', 'EnableCache') then
    FCache := TMemIniFile.Create(ChangeFileExt(FConfiguration.Path, '.Cache.ini'));
  if Assigned(FCache) then
    for Index := 0 to Count - 1 do
      if Cached(Item(Index).FileName) then
        SetResult(Index, fsCached, Item(Index).OriginalSize, '');
  if FConfiguration.GetBoolean('General', 'ParallelEnabled') and not FConfiguration.GetBoolean('General', 'AllowDuplicates') then
    WorkerCount := EnsureRange(FConfiguration.GetInteger('General', 'ParallelCount'), 1, 64)
  else
    WorkerCount := 1;
  WorkerCount := Min(WorkerCount, Count);
  SetLength(FWorkers, WorkerCount);
  for Index := 0 to WorkerCount - 1 do
  begin
    FWorkers[Index] := TOptimizerWorker.Create(Self);
    FWorkers[Index].Start;
  end;
end;

procedure TOptimizerService.Stop;
var
  Index: Integer;
begin
  FLock.Enter;
  try
    FCancelled := True;
  finally
    FLock.Leave;
  end;
  for Index := 0 to High(FWorkers) do
    FWorkers[Index].WaitFor;
  for Index := 0 to High(FWorkers) do
    FWorkers[Index].Free;
  SetLength(FWorkers, 0);
  FLock.Enter;
  try
    for Index := 0 to High(FItems) do
      if FItems[Index].State = fsPending then
        FItems[Index].State := fsCancelled;
  finally
    FLock.Leave;
  end;
  if Assigned(FCache) then
    FCache.UpdateFile;
end;

procedure TOptimizerService.ProcessItem(const AIndex: Integer);
var
  ErrorText, FileName, WorkingFile, TempDirectory: string;
  SizeBefore, SizeAfter: Int64;
begin
  FileName := Item(AIndex).FileName;
  SizeBefore := FileSizeOrZero(FileName);
  if (FConfiguration.GetText('General', 'IncludeMask') <> '') and not MatchesMask(FileName, FConfiguration.GetText('General', 'IncludeMask')) then
  begin
    SetResult(AIndex, fsSkipped, SizeBefore, '');
    Exit;
  end;
  if MatchesMask(FileName, FConfiguration.GetText('General', 'ExcludeMask')) then
  begin
    SetResult(AIndex, fsSkipped, SizeBefore, '');
    Exit;
  end;
  if SizeBefore = 0 then
  begin
    SetResult(AIndex, fsSkipped, 0, '');
    Exit;
  end;
  if Cached(FileName) then
  begin
    SetResult(AIndex, fsCached, SizeBefore, '');
    Exit;
  end;
  TempDirectory := FConfiguration.GetText('General', 'TempDirectory');
  if TempDirectory = '' then
    TempDirectory := GetTempDir(False);
  if not DirectoryExists(TempDirectory) then
    ForceDirectories(TempDirectory);
  WorkingFile := NewTempPath(TempDirectory) + Item(AIndex).DetectedExtension;
  if not CopyFileData(FileName, WorkingFile) then
  begin
    SetResult(AIndex, fsFailed, SizeBefore, 'Cannot create working copy');
    Exit;
  end;
  try
    RunFormatPlugins(AIndex, WorkingFile);
    SizeAfter := FileSizeOrZero(WorkingFile);
    if IsCancelled then
      SetResult(AIndex, fsCancelled, SizeBefore, '')
    else if SizeAfter >= SizeBefore then
    begin
      if Item(AIndex).PluginRuns = 0 then
        SetResult(AIndex, fsSkipped, SizeBefore, 'No compatible plugin programs were run')
      else
      begin
        SetResult(AIndex, fsDone, SizeBefore, Item(AIndex).LastPluginError);
        UpdateCache(FileName);
      end;
    end
    else if CommitFile(FileName, WorkingFile, ErrorText) then
    begin
      SetResult(AIndex, fsDone, SizeAfter, '');
      UpdateCache(FileName);
    end
    else
      SetResult(AIndex, fsFailed, SizeBefore, ErrorText);
  finally
    if not FConfiguration.GetBoolean('General', 'Debug') then
      SysUtils.DeleteFile(WorkingFile);
  end;
end;

procedure TOptimizerService.RunFormatPlugins(const AIndex: Integer; const AWorkingFile: string);
var
  acTmpFilePdf: string;
  bIsAPNG, bIsEXESFX, bIsJPEGCMYK, bIsPDFLayered, bIsPNG9Patch, bJSAdditional: Boolean;
  gudtOptions: TOriginalOptions;
  iLevel: Integer;
  sExtensionByContent, sFlags, sInputFile, sPluginsDirectory, sTmpOutputFile: string;
begin
  gudtOptions.acCSSTemplate := FConfiguration.GetText('CSS', 'Template');
  gudtOptions.acJSAdditionalExtensions := FConfiguration.GetText('JS', 'AdditionalExtensions');
  gudtOptions.acPDFProfile := FConfiguration.GetText('PDF', 'Profile');
  gudtOptions.bBMPCopyMetadata := FConfiguration.GetBoolean('BMP', 'CopyMetadata');
  gudtOptions.bCSSEnableTidy := FConfiguration.GetBoolean('CSS', 'EnableTidy');
  gudtOptions.bDebug := FConfiguration.GetBoolean('General', 'Debug');
  gudtOptions.bEXEDisablePETrim := FConfiguration.GetBoolean('EXE', 'DisablePETrim');
  gudtOptions.bEXEEnableUPX := FConfiguration.GetBoolean('EXE', 'EnableUPX');
  gudtOptions.bGIFAllowLossy := FConfiguration.GetBoolean('GIF', 'AllowLossy');
  gudtOptions.bGIFCopyMetadata := FConfiguration.GetBoolean('GIF', 'CopyMetadata');
  gudtOptions.bGZCopyMetadata := FConfiguration.GetBoolean('GZ', 'CopyMetadata');
  gudtOptions.bHTMLEnableTidy := FConfiguration.GetBoolean('HTML', 'EnableTidy');
  gudtOptions.bJPEGAllowLossy := FConfiguration.GetBoolean('JPEG', 'AllowLossy');
  gudtOptions.bJPEGCopyMetadata := FConfiguration.GetBoolean('JPEG', 'CopyMetadata');
  gudtOptions.bJPEGUseArithmeticEncoding := FConfiguration.GetBoolean('JPEG', 'UseArithmeticEncoding');
  gudtOptions.bJSEnableJSMin := FConfiguration.GetBoolean('JS', 'EnableJSMin');
  gudtOptions.bLUAEnableLeanify := FConfiguration.GetBoolean('LUA', 'EnableLeanify');
  gudtOptions.bMiscCopyMetadata := FConfiguration.GetBoolean('Misc', 'CopyMetadata');
  gudtOptions.bMiscDisable := FConfiguration.GetBoolean('Misc', 'Disable');
  gudtOptions.bMP3CopyMetadata := FConfiguration.GetBoolean('MP3', 'CopyMetadata');
  gudtOptions.bMP4CopyMetadata := FConfiguration.GetBoolean('MP4', 'CopyMetadata');
  gudtOptions.bPCXCopyMetadata := FConfiguration.GetBoolean('PCX', 'CopyMetadata');
  gudtOptions.bPDFSkipLayered := FConfiguration.GetBoolean('PDF', 'SkipLayered');
  gudtOptions.bPNGAllowLossy := FConfiguration.GetBoolean('PNG', 'AllowLossy');
  gudtOptions.bPNGCopyMetadata := FConfiguration.GetBoolean('PNG', 'CopyMetadata');
  gudtOptions.bTGACopyMetadata := FConfiguration.GetBoolean('TGA', 'CopyMetadata');
  gudtOptions.bTIFFCopyMetadata := FConfiguration.GetBoolean('TIFF', 'CopyMetadata');
  gudtOptions.bWAVCopyMetadata := FConfiguration.GetBoolean('WAV', 'CopyMetadata');
  gudtOptions.bWAVStripSilence := FConfiguration.GetBoolean('WAV', 'StripSilence');
  gudtOptions.bWEBPAllowLossy := FConfiguration.GetBoolean('WEBP', 'AllowLossy');
  gudtOptions.bXMLEnableLeanify := FConfiguration.GetBoolean('XML', 'EnableLeanify');
  gudtOptions.bZIPCopyMetadata := FConfiguration.GetBoolean('ZIP', 'CopyMetadata');
  gudtOptions.bZIPRecurse := FConfiguration.GetBoolean('ZIP', 'Recurse');
  gudtOptions.iLeanifyIterations := FConfiguration.GetInteger('General', 'LeanifyIterations');
  gudtOptions.iLevel := EnsureRange(FConfiguration.GetInteger('General', 'Level'), 0, 9);
  gudtOptions.iPDFCustomDPI := EnsureRange(FConfiguration.GetInteger('PDF', 'CustomDPI'), 50, 3000);
  gudtOptions.iPNGWolfIterations := FConfiguration.GetInteger('General', 'PNGWolfIterations');
  sInputFile := AWorkingFile;
  sPluginsDirectory := IncludeTrailingPathDelimiter(FPluginDirectory);
  sExtensionByContent := ' ' + GetExtensionByContent(sInputFile, gudtOptions.acJSAdditionalExtensions) + ' ';
    if PosEx(sExtensionByContent, KS_EXTENSION_AVIF) > 0 then
    begin
      sFlags := '';
      RunPlugin(AIndex, 'ImageMagick (1/1)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet -define heic:speed=1 ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_BMP) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bBMPCopyMetadata then
        sFlags := sFlags + '-strip ';
      RunPlugin(AIndex, 'ImageMagick (1/2)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet -compress RLE ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'ImageWorsener (2/2)', sPluginsDirectory + 'imagew.exe -opt bmp:version=auto -noresize -zipcmprlevel 9 -outfmt bmp -compress "rle" "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_CSS) > 0 then
    begin
      if gudtOptions.bCSSEnableTidy then
      begin
        RunPlugin(AIndex, 'CSSTidy (1/2)', sPluginsDirectory + 'csstidy.exe "%INPUTFILE%" --template=' + gudtOptions.acCSSTemplate + ' "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        RunPlugin(AIndex, 'Minify (2/2)', sPluginsDirectory + 'minify.exe "%INPUTFILE%" --output "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_DLL) > 0 then
    begin
      if not gudtOptions.bEXEDisablePETrim then
        RunPlugin(AIndex, 'PETrim (1/3)', sPluginsDirectory + 'petrim.exe "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'strip (2/3)', sPluginsDirectory + 'strip.exe --strip-all -o "%TMPOUTPUTFILE%" "%INPUTFILE%"', sInputFile, '', 0, 0);
      if gudtOptions.bEXEEnableUPX then
      begin
        sFlags := '';
        if gudtOptions.iLevel < 3 then
          sFlags := sFlags + '-1 '
        else if gudtOptions.iLevel < 5 then
          sFlags := sFlags + '-9 '
        else if gudtOptions.iLevel < 7 then
          sFlags := sFlags + '-9 --best '
        else if gudtOptions.iLevel < 9 then
          sFlags := sFlags + '-9 --best --lzma '
        else
          sFlags := sFlags + '-9 --best --lzma --ultra-brute --crp-ms=999999 ';
        RunPlugin(AIndex, 'UPX (3/3)', sPluginsDirectory + 'upx.exe --no-backup --force ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_EXE) > 0 then
    begin
      if not IsEXESFX(sInputFile) then
      begin
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'Leanify (1/4)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
        if not gudtOptions.bEXEDisablePETrim then
          RunPlugin(AIndex, 'PETrim (2/4)', sPluginsDirectory + 'petrim.exe /StripFixups:Y "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
        RunPlugin(AIndex, 'strip (3/4)', sPluginsDirectory + 'strip.exe --strip-all -o "%TMPOUTPUTFILE%" "%INPUTFILE%"', sInputFile, '', 0, 0);
        if gudtOptions.bEXEEnableUPX then
        begin
          sFlags := '--no-backup --force ';
          if gudtOptions.iLevel < 3 then
            sFlags := sFlags + '-1 '
          else if gudtOptions.iLevel < 5 then
            sFlags := sFlags + '-9 '
          else if gudtOptions.iLevel < 7 then
            sFlags := sFlags + '-9 --best '
          else if gudtOptions.iLevel < 9 then
            sFlags := sFlags + '-9 --best --lzma '
          else
            sFlags := sFlags + '-9 --best --lzma --ultra-brute --crp-ms=999999 ';
          RunPlugin(AIndex, 'UPX (4/4)', sPluginsDirectory + 'upx.exe ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
        end;
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_FLAC) > 0 then
    begin
      if not gudtOptions.bWAVCopyMetadata then
      begin
        sTmpOutputFile := StringReplaceAll(sInputFile, '.flac', '-stripped.flac');
        if sTmpOutputFile = sInputFile then
          sTmpOutputFile := sTmpOutputFile + '-stripped.flac';
        RunPlugin(AIndex, 'shntool (1/4)', sPluginsDirectory + 'shntool.exe strip -q -O always -d "' + ExtractFileDir(sInputFile) + '" "%INPUTFILE%"', sInputFile, '', 0, 0);
        if (FileSizeOrZero(sTmpOutputFile) > 0) and (FileSizeOrZero(sTmpOutputFile) < FileSizeOrZero(sInputFile)) then
          CopyFileData(sTmpOutputFile, sInputFile);
        if not gudtOptions.bDebug then
          SysUtils.DeleteFile(sTmpOutputFile);
        if gudtOptions.bWAVStripSilence then
        begin
          sTmpOutputFile := StringReplaceAll(sInputFile, '.flac', '-trimmed.flac');
          if sTmpOutputFile = sInputFile then
            sTmpOutputFile := sTmpOutputFile + '-trimmed.flac';
          RunPlugin(AIndex, 'shntool (2/4)', sPluginsDirectory + 'shntool.exe trim -q -O always -d "' + ExtractFileDir(sInputFile) + '" "%INPUTFILE%"', sInputFile, '', 0, 0);
          if (FileSizeOrZero(sTmpOutputFile) > 0) and (FileSizeOrZero(sTmpOutputFile) < FileSizeOrZero(sInputFile)) then
            CopyFileData(sTmpOutputFile, sInputFile);
          if not gudtOptions.bDebug then
            SysUtils.DeleteFile(sTmpOutputFile);
        end;
      end;
      sFlags := '';
      if gudtOptions.bMiscCopyMetadata then
        sFlags := sFlags + '--keep-foreign-metadata ';
      if gudtOptions.iLevel < 3 then
        sFlags := sFlags + '-1 '
      else if gudtOptions.iLevel < 5 then
        sFlags := sFlags + '-8 --best '
      else if gudtOptions.iLevel < 7 then
        sFlags := sFlags + '-8 --best -e '
      else
        sFlags := sFlags + '-8 --best -ep ';
      RunPlugin(AIndex, 'FLAC (3/4)', sPluginsDirectory + 'flac.exe --force -s ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      if gudtOptions.iLevel >= 9 then
        RunPlugin(AIndex, 'FLACOut (4/4)', sPluginsDirectory + 'flacout.exe /q /y "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_GIF) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bGIFCopyMetadata then
        sFlags := sFlags + '-strip ';
      RunPlugin(AIndex, 'ImageMagick (1/2)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet -layers optimize -compress LZW ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      iLevel := 3;
      sFlags := sFlags + '-O' + IntToStr(iLevel) + ' ';
      if not gudtOptions.bGIFCopyMetadata then
        sFlags := sFlags + '--no-comments --no-extensions --no-names ';
      if gudtOptions.bGIFAllowLossy then
        sFlags := sFlags + '--lossy=85 ';
      RunPlugin(AIndex, 'gifsicle (2/2)', sPluginsDirectory + 'gifsicle.exe -w -j --no-conserve-memory -o "%TMPOUTPUTFILE%" ' + sFlags + '"%INPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_GZ) > 0 then
    begin
      if not gudtOptions.bGZCopyMetadata then
      begin
        RunPlugin(AIndex, 'libdeflate (1/8)', sPluginsDirectory + 'libdeflate.bat "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        if gudtOptions.bGZCopyMetadata then
          sFlags := sFlags + '--keep-exif ';
        RunPlugin(AIndex, 'Leanify (2/8)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
      sFlags := '';
      iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
      sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'advdef (3/8)', sPluginsDirectory + 'advdef.exe -z -q -4 ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'zRecompress (4/8)', sPluginsDirectory + 'zRecompress.exe -tgz "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if not gudtOptions.bGZCopyMetadata then
        sFlags := sFlags + '-strip ';
      iLevel := min(gudtOptions.iLevel * 8 div 9, 8) + 1;
      if iLevel = 9 then
        iLevel := 90032;
      sFlags := sFlags + '-' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'ECT (5/8)', sPluginsDirectory + 'ECT.exe -quiet --mt-deflate --mt-file --allfilters -gzip ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if gudtOptions.bGZCopyMetadata then
        sFlags := sFlags + '/c ';
      RunPlugin(AIndex, 'DeflOpt (6/8)', sPluginsDirectory + 'deflopt.exe /a /b /s ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'defluff (7/8)', sPluginsDirectory + 'defluff.bat "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'DeflOpt (8/8)', sPluginsDirectory + 'deflopt.exe /a /b /s ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_HTML) > 0 then
    begin
      if gudtOptions.bHTMLEnableTidy then
      begin
        RunPlugin(AIndex, 'tidy (1/3)', sPluginsDirectory + 'tidy.exe -config tidy.config -quiet -output "%TMPOUTPUTFILE%" "%INPUTFILE%" ', sInputFile, '', 0, 0);
        RunPlugin(AIndex, 'Minify (2/3)', sPluginsDirectory + 'minify.exe "%INPUTFILE%" --output "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'Leanify (3/3)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_ICO) > 0 then
    begin
      if not gudtOptions.bPNGCopyMetadata then
      begin
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'Leanify (2/2)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_JP2) > 0 then
    begin
      sFlags := '';
      RunPlugin(AIndex, 'ImageMagick (1/1)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet -quality 0 ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_JPG) > 0 then
    begin
      bIsJPEGCMYK := IsJPEGCMYK(sInputFile);
      sFlags := '';
      iLevel := min(gudtOptions.iLevel * 4 div 9, 4);
      sFlags := sFlags + '-s' + IntToStr(iLevel) + ' ';
      if gudtOptions.bJPEGAllowLossy then
        sFlags := sFlags + '-quality=95 '
      else
        sFlags := sFlags + '-lossless ';
      if gudtOptions.bJPEGCopyMetadata then
        sFlags := sFlags + '-nostrip ';
      RunPlugin(AIndex, 'pingo (1/11)', sPluginsDirectory + 'pingo.exe ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      if (gudtOptions.bJPEGAllowLossy) and (not gudtOptions.bJPEGCopyMetadata) then
        RunPlugin(AIndex, 'cjpegli (2/11)', sPluginsDirectory + 'cjpegli.exe -q 70 "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      if (gudtOptions.bJPEGAllowLossy) and (not gudtOptions.bJPEGCopyMetadata) then
        RunPlugin(AIndex, 'Guetzli (3/11)', sPluginsDirectory + 'guetzli.exe --auto --quality 90 "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      if gudtOptions.bJPEGAllowLossy then
      begin
        sFlags := '';
        if not gudtOptions.bJPEGCopyMetadata then
          sFlags := sFlags + '--strip ';
        if gudtOptions.iLevel >= 5 then
          sFlags := sFlags + '--accurate ';
        RunPlugin(AIndex, 'jpeg-recompress (4/11)', sPluginsDirectory + 'jpeg-recompress.exe --method smallfry --quality high --min 60 --subsample disable --quiet ' + sFlags + '"%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      end;
      if not bIsJPEGCMYK then
      begin
        sFlags := '';
        if gudtOptions.bJPEGCopyMetadata then
          sFlags := sFlags + '-zt '
        else
          sFlags := sFlags + '-purejpg -di -dx -dt -zt ';
        RunPlugin(AIndex, 'jhead (5/11)', sPluginsDirectory + 'jhead.exe -q -autorot ' + sFlags + ' "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
      sFlags := '';
      if gudtOptions.bJPEGCopyMetadata then
        sFlags := sFlags + '--keep-exif --keep-icc --jpeg-keep-all ';
      if gudtOptions.bJPEGUseArithmeticEncoding then
        sFlags := sFlags + '--jpeg-arithmetic ';
      if gudtOptions.iLeanifyIterations <> -1 then
        iLevel := gudtOptions.iLeanifyIterations
      else
        iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
      sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'Leanify (6/11)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      if gudtOptions.bJPEGAllowLossy then
      begin
        sFlags := '';
        if not gudtOptions.bJPEGCopyMetadata then
          sFlags := sFlags + '-strip ';
        RunPlugin(AIndex, 'ImageMagick (7/11)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet -interlace Plane -define jpeg:optimize-coding=True ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      end;
      sFlags := '';
      if not gudtOptions.bJPEGCopyMetadata then
        sFlags := sFlags + '--strip-all ';
      if gudtOptions.bJPEGUseArithmeticEncoding then
        sFlags := sFlags + '--with-arith ';
      sFlags := sFlags + '-w ' + IntToStr(GetSystemThreadCount) + ' ';
      RunPlugin(AIndex, 'jpegoptim (8/11)', sPluginsDirectory + 'jpegoptim.exe -o -q --all-progressive --nofix ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if gudtOptions.bJPEGUseArithmeticEncoding then
        sFlags := sFlags + '-arithmetic ';
      if gudtOptions.bJPEGCopyMetadata then
        sFlags := sFlags + '-copy all '
      else
        sFlags := sFlags + '-copy none ';
      RunPlugin(AIndex, 'jpegtran (9/11)', sPluginsDirectory + 'jpegtran.exe -progressive -optimize ' + sFlags + '"%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'mozjpegtran (10/11)', sPluginsDirectory + 'mozjpegtran.exe -outfile "%TMPOUTPUTFILE%" -progressive -optimize -perfect ' + sFlags + '"%INPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if not gudtOptions.bJPEGCopyMetadata then
        sFlags := sFlags + '-strip ';
      if not gudtOptions.bPNGAllowLossy then
        sFlags := sFlags + '--strict ';
      iLevel := min(gudtOptions.iLevel * 8 div 9, 8) + 1;
      if iLevel = 9 then
        iLevel := 90032;
      sFlags := sFlags + '-' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'ECT (11/11)', sPluginsDirectory + 'ECT.exe -quiet --mt-deflate --mt-file --allfilters -progressive ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_JXL) > 0 then
    begin
      sFlags := '';
      iLevel := min(gudtOptions.iLevel * 9 div 9, 9);
      sFlags := sFlags + 'jxl:effort=' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'ImageMagick (1/1)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    bJSAdditional := (((gudtOptions.acJSAdditionalExtensions <> '')) and (PosEx(sExtensionByContent, ' ' + StringReplaceAll(gudtOptions.acJSAdditionalExtensions, ',', ' ') + ' ') > 0));
    if (PosEx(sExtensionByContent, KS_EXTENSION_JS) > 0) or (bJSAdditional) then
    begin
      if (gudtOptions.bJSEnableJSMin) or (bJSAdditional) then
      begin
        RunPlugin(AIndex, 'jsmin (1/2)', sPluginsDirectory + 'jsmin.bat "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        RunPlugin(AIndex, 'Minify (2/2)', sPluginsDirectory + 'minify.exe "%INPUTFILE%" --output "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_LUA) > 0 then
    begin
      if gudtOptions.bLUAEnableLeanify then
      begin
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'Leanify (1/1)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_MIME) > 0 then
    begin
      sFlags := '';
      if gudtOptions.iLeanifyIterations <> -1 then
        iLevel := gudtOptions.iLeanifyIterations
      else
        iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
      sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'Leanify (1/1)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_MKV) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bMP4CopyMetadata then
        sFlags := sFlags + '-map_metadata -1 ';
      RunPlugin(AIndex, 'ffmpeg (1/2)', sPluginsDirectory + 'ffmpeg.exe -i "%INPUTFILE%" -vcodec copy -acodec copy -map 0 ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'mkclean (2/2)', sPluginsDirectory + 'mkclean.exe --optimize --unsafe --quiet "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_MNG) > 0 then
    begin
      sFlags := '';
      iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
      sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'advmng (1/1)', sPluginsDirectory + 'advmng.exe -z -r -q -4 ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_MP3) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bMP3CopyMetadata then
        sFlags := sFlags + '-t -s ';
      RunPlugin(AIndex, 'MP3packer (1/1)', sPluginsDirectory + 'mp3packer.exe ' + sFlags + '-z -a "" -A -f "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_MP4) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bMP4CopyMetadata then
        sFlags := sFlags + '-map_metadata -1 ';
      RunPlugin(AIndex, 'ffmpeg (1/2)', sPluginsDirectory + 'ffmpeg.exe -i "%INPUTFILE%" -vcodec copy -acodec copy -map 0 ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'mp4v2 (2/2)', sPluginsDirectory + 'mp4file.exe --optimize -q "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_OBJ) > 0 then
      RunPlugin(AIndex, 'strip (1/1)', sPluginsDirectory + 'strip.exe --strip-all -o "%TMPOUTPUTFILE%" "%INPUTFILE%"', sInputFile, '', 0, 0);
    if PosEx(sExtensionByContent, KS_EXTENSION_OGG) > 0 then
    begin
      RunPlugin(AIndex, 'OptiVorbis (1/2)', sPluginsDirectory + 'optivorbis.exe --vendor_string_action empty --comment_fields_action delete "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'rehuff_theora (2/2)', sPluginsDirectory + 'rehuff_theora.exe "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_OGV) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bMP4CopyMetadata then
        sFlags := sFlags + '-map_metadata -1 ';
      RunPlugin(AIndex, 'ffmpeg (1/2)', sPluginsDirectory + 'ffmpeg.exe -i "%INPUTFILE%" -vcodec copy -acodec copy -map 0 ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'rehuff_theora (2/2)', sPluginsDirectory + 'rehuff_theora.exe "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_OLE) > 0 then
    begin
      RunPlugin(AIndex, 'Document Press (1/2)', sPluginsDirectory + 'docprc.exe -opt "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'Best CFBF (2/2)', sPluginsDirectory + 'bestcfbf.exe "%INPUTFILE%" "%TMPOUTPUTFILE%" -v4', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_PCX) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bPCXCopyMetadata then
        sFlags := sFlags + '-strip ';
      RunPlugin(AIndex, 'ImageMagick (1/1)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet -compress RLE ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_PDF) > 0 then
    begin
      bIsPDFLayered := IsPDFLayered(sInputFile);
      if (not bIsPDFLayered) or (not gudtOptions.bPDFSkipLayered) or (SameText(gudtOptions.acPDFProfile, 'none')) then
      begin
        RunPlugin(AIndex, 'mutool (1/4)', sPluginsDirectory + 'mutool.exe clean -g -z "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        if not EndsText('.ai', sInputFile) then
        begin
          sFlags := '';
          if SameText(gudtOptions.acPDFProfile, 'Custom') then
            sFlags := sFlags + '-dPDFSETTINGS=/ebook -dDownsampleColorImages=True -dColorImageResolution=' + IntToStr(gudtOptions.iPDFCustomDPI) + ' -dDownsampleGrayImages=True -dGrayImageResolution=' + IntToStr(gudtOptions.iPDFCustomDPI) + ' -dDownsampleMonoImages=True -dMonoImageResolution=' + IntToStr(gudtOptions.iPDFCustomDPI) + ' '
          else if SameText(gudtOptions.acPDFProfile, 'none') then
            sFlags := sFlags + '-dPDFSETTINGS=/default -c ".setpdfwrite <</ColorACSImageDict>[1 1 1 1] /VSamples [1 1 1 1] /Blend 1>> /GrayACSImageDict<</QFactor>[1 1 1 1] /VSamples [1 1 1 1] /Blend 1>>>> setdistillerparams" '
          else
            sFlags := sFlags + '-dPDFSETTINGS=/' + gudtOptions.acPDFProfile + ' ';
          sFlags := sFlags + '-dColorImageDownsampleType=/Bicubic -dGrayImageDownsampleType=/Bicubic -dMonoImageDownsampleType=/Bicubic -dOptimize=True -dConvertCMYKImagesToRGB=True -dColorConversionStrategy=/sRGB -dPrinted=False -q -dBATCH -dNOPAUSE -dSAFER -dDELAYSAFER -dNOPROMPT -sDEVICE=pdfwrite -dDetectDuplicateImages=True -dAutoRotatePages=/None -dCompatibilityLevel=1.4 ';
          acTmpFilePdf := sInputFile + '.pdf';
            RunPlugin(AIndex, 'Ghostcript (2/4)', sPluginsDirectory + 'gswin64c.exe ' + sFlags + '-sOutputFile="' + acTmpFilePdf + '" "%INPUTFILE%"', sInputFile, '', 0, 0);
          if FileSizeOrZero(acTmpFilePdf) < FileSizeOrZero(sInputFile) then
          begin
            if (FileSizeOrZero(acTmpFilePdf) > 3000) and (FileSizeOrZero(sInputFile) > 20000) then
              CopyFileData(acTmpFilePdf, sInputFile);
          end;
          if not gudtOptions.bDebug then
            SysUtils.DeleteFile(acTmpFilePdf);
        end;
        RunPlugin(AIndex, 'cpdf (3/4)', sPluginsDirectory + 'cpdf.exe -squeeze "%INPUTFILE%" -o "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        RunPlugin(AIndex, 'qpdf (4/4)', sPluginsDirectory + 'qpdf.exe "%INPUTFILE%" --compress-streams=y --decode-level=generalized --recompress-flate --compression-level=9 --optimize-images --object-streams=generate "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_PNG) > 0 then
    begin
      bIsAPNG := IsAPNG(sInputFile);
      bIsPNG9Patch := EndsText('.9.png', sInputFile);
      if bIsAPNG then
        RunPlugin(AIndex, 'apngopt (1/16)', sPluginsDirectory + 'apngopt.exe "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      if not bIsPNG9Patch then
      begin
        if (gudtOptions.bPNGAllowLossy) and (not bIsAPNG) then
        begin
          sFlags := '';
          if not gudtOptions.bPNGCopyMetadata then
            sFlags := sFlags + '--strip ';
          RunPlugin(AIndex, 'pngquant (2/16)', sPluginsDirectory + 'pngquant.exe ' + sFlags + '--quality=85-95 --speed 1 --ext .png --force "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
        end;
        sFlags := '';
        if gudtOptions.bPNGCopyMetadata then
          sFlags := sFlags + '-KeepPhysicalPixelDimensions ';
        RunPlugin(AIndex, 'PngOptimizer (3/16)', sPluginsDirectory + 'PngOptimizer.exe ' + sFlags + '-file:"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
      if (not bIsAPNG) and (not bIsPNG9Patch) then
      begin
        if PosEx(sExtensionByContent, KS_EXTENSION_ICO) = 0 then
        begin
          sFlags := '';
          iLevel := min(gudtOptions.iLevel * 3 div 9, 3) + 1;
          sFlags := sFlags + '-o' + IntToStr(iLevel) + ' ';
          if gudtOptions.bPNGCopyMetadata then
            sFlags := sFlags + '-md keep all '
          else
            sFlags := sFlags + '-tz -md remove all -a1 -g1 ';
          if gudtOptions.bPNGAllowLossy then
            sFlags := sFlags + '-l ';
          RunPlugin(AIndex, 'TruePNG (4/16)', sPluginsDirectory + 'truepng.exe ' + sFlags + '/i0 /nc /tz /quiet /y /out "%TMPOUTPUTFILE%" "%INPUTFILE%"', sInputFile, '', 0, 0);
        end;
        if PosEx(' ' + GetExtensionByContent(sInputFile, gudtOptions.acJSAdditionalExtensions, True) + ' ', KS_EXTENSION_JPG) = 0 then
        begin
          sFlags := '';
          if gudtOptions.bPNGCopyMetadata then
            sFlags := sFlags + '/k1 '
          else
            sFlags := sFlags + '/kacTL,fcTL,fdAT ';
          iLevel := max((gudtOptions.iLevel * 3 div 9) - 3, 0);
          sFlags := sFlags + '/s' + IntToStr(iLevel) + ' ';
          RunPlugin(AIndex, 'PNGOut (5/16)', sPluginsDirectory + 'pngout.exe /q /y /r /d0 /mincodes0 ' + sFlags + '"%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        end;
      end;
      sFlags := '';
      iLevel := min(gudtOptions.iLevel * 6 div 9, 6);
      sFlags := sFlags + '-o' + IntToStr(iLevel) + ' ';
      if gudtOptions.bPNGAllowLossy then
        sFlags := sFlags + '--scale16 ';
      if bIsAPNG then
      begin
        sFlags := sFlags + '--strip safe ';
        RunPlugin(AIndex, 'OxiPNG (6/16)', sPluginsDirectory + 'oxipng.exe --zopfli --alpha --quiet ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end
      else
      begin
        if not gudtOptions.bPNGCopyMetadata then
          sFlags := sFlags + '--strip all '
        else
          sFlags := sFlags + '--strip safe ';
        RunPlugin(AIndex, 'OxiPNG (7/16)', sPluginsDirectory + 'oxipng.exe --zopfli --alpha --quiet ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
      if not bIsAPNG then
      begin
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        if not gudtOptions.bPNGCopyMetadata then
          RunPlugin(AIndex, 'Leanify (8/16)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
        sFlags := '';
        if gudtOptions.iPNGWolfIterations <> -1 then
          iLevel := gudtOptions.iPNGWolfIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '--out-deflate=zopfli,iter=' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'pngwolf (9/16)', sPluginsDirectory + 'pngwolf.exe ' + sFlags + '--in="%INPUTFILE%" --out="%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
        if not bIsPNG9Patch then
        begin
          RunPlugin(AIndex, 'pngrewrite (10/16)', sPluginsDirectory + 'pngrewrite.exe "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
          sFlags := '';
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
          sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
          if not gudtOptions.bPNGCopyMetadata then
            RunPlugin(AIndex, 'advpng (11/16)', sPluginsDirectory + 'advpng.exe -z -q -4 ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
        end;
      end;
      sFlags := '';
      if bIsAPNG then
        sFlags := sFlags + '--reuse '
      else if not gudtOptions.bPNGCopyMetadata then
        sFlags := sFlags + '-strip ';
      iLevel := min(gudtOptions.iLevel * 8 div 9, 8) + 1;
      if iLevel = 9 then
        iLevel := 90032;
      sFlags := sFlags + '-' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'ECT (12/16)', sPluginsDirectory + 'ECT.exe -quiet --mt-deflate --mt-file --allfilters ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      iLevel := min(gudtOptions.iLevel * 4 div 9, 4);
      sFlags := sFlags + '-s' + IntToStr(iLevel) + ' ';
      if gudtOptions.bPNGCopyMetadata then
        sFlags := sFlags + '-nostrip ';
      if gudtOptions.bPNGAllowLossy then
        sFlags := sFlags + '-quality=95 '
      else
        sFlags := sFlags + '-lossless ';
      RunPlugin(AIndex, 'pingo (13/16)', sPluginsDirectory + 'pingo.exe ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if gudtOptions.bPNGCopyMetadata then
        sFlags := sFlags + '/k ';
      if (not bIsAPNG) and (not bIsPNG9Patch) then
        RunPlugin(AIndex, 'DeflOpt (14/16)', sPluginsDirectory + 'deflopt.exe /a /b /s ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'defluff (15/16)', sPluginsDirectory + 'defluff.bat "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      if (not bIsAPNG) and (not bIsPNG9Patch) then
        RunPlugin(AIndex, 'DeflOpt (16/16)', sPluginsDirectory + 'deflopt.exe /a /b /s ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_SWF) > 0 then
    begin
      sTmpOutputFile := ChangeFileExt(sInputFile, '.$wf');
      RunPlugin(AIndex, 'flasm (1/5)', sPluginsDirectory + 'flasm.exe -x "%INPUTFILE%"', sInputFile, '', 0, 0);
      CopyFileData(sTmpOutputFile, sInputFile);
      SysUtils.DeleteFile(sTmpOutputFile);
      RunPlugin(AIndex, 'flasm (2/5)', sPluginsDirectory + 'flasm.exe -u "%INPUTFILE%"', sInputFile, '', 0, 0);
      CopyFileData(sTmpOutputFile, sInputFile);
      SysUtils.DeleteFile(sTmpOutputFile);
      RunPlugin(AIndex, 'flasm (3/5)', sPluginsDirectory + 'flasm.exe -z "%INPUTFILE%"', sInputFile, '', 0, 0);
      if (FileSizeOrZero(sTmpOutputFile) > 0) and (FileSizeOrZero(sTmpOutputFile) < FileSizeOrZero(sInputFile)) then
        CopyFileData(sTmpOutputFile, sInputFile);
      SysUtils.DeleteFile(sTmpOutputFile);
      RunPlugin(AIndex, 'zRecompress (4/5)', sPluginsDirectory + 'zRecompress.exe -tswf-lzma "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if gudtOptions.iLeanifyIterations <> -1 then
        iLevel := gudtOptions.iLeanifyIterations
      else
        iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
      sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'Leanify (5/5)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_SQLITE) > 0 then
      RunPlugin(AIndex, 'sqlite (1/1)', sPluginsDirectory + 'sqlite.bat "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    if PosEx(sExtensionByContent, KS_EXTENSION_TAR) > 0 then
    begin
      sFlags := '';
      if gudtOptions.bGZCopyMetadata then
        sFlags := sFlags + '--keep-exif ';
      if gudtOptions.iLeanifyIterations <> -1 then
        iLevel := gudtOptions.iLeanifyIterations
      else
        iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
      sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'Leanify (1/1)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_TENCENTQQ) > 0 then
    begin
      if not gudtOptions.bPNGCopyMetadata then
      begin
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'Leanify (1/1)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_TGA) > 0 then
    begin
      sFlags := '';
      if not gudtOptions.bTGACopyMetadata then
        sFlags := sFlags + '-strip ';
      RunPlugin(AIndex, 'ImageMagick (1/1)', sPluginsDirectory + 'magick.exe convert -quiet -compress RLE ' + sFlags + '"%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_TIFF) > 0 then
    begin
      bIsJPEGCMYK := IsJPEGCMYK(sInputFile);
      if not bIsJPEGCMYK then
      begin
        sFlags := '';
        if gudtOptions.bTIFFCopyMetadata then
          sFlags := sFlags + '-zt '
        else
          sFlags := sFlags + '-purejpg -di -dx -dt -zt ';
        RunPlugin(AIndex, 'jhead (1/6)', sPluginsDirectory + 'jhead.exe -q -autorot ' + sFlags + ' "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
      if not gudtOptions.bTIFFCopyMetadata then
        RunPlugin(AIndex, 'ImageMagick (2/6)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet -compress ZIP -strip "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if not gudtOptions.bTIFFCopyMetadata then
        sFlags := sFlags + '--strip-all ';
      if gudtOptions.bJPEGUseArithmeticEncoding then
        sFlags := sFlags + '--with-arith ';
      sFlags := sFlags + '-w ' + IntToStr(GetSystemThreadCount) + ' ';
      RunPlugin(AIndex, 'jpegoptim (3/6)', sPluginsDirectory + 'jpegoptim.exe -o -q --all-progressive --nofix ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if gudtOptions.bJPEGUseArithmeticEncoding then
        sFlags := sFlags + '-arithmetic ';
      if gudtOptions.bTIFFCopyMetadata then
        sFlags := sFlags + '-copy all '
      else
        sFlags := sFlags + '-copy none ';
      RunPlugin(AIndex, 'jpegtran (4/6)', sPluginsDirectory + 'jpegtran.exe -progressive -optimize ' + sFlags + '"%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'mozjpegtran (5/6)', sPluginsDirectory + 'mozjpegtran.exe -outfile "%TMPOUTPUTFILE%" -progressive -optimize -perfect ' + sFlags + '"%INPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'tinydng (6/6)', sPluginsDirectory + 'tinydng-cli.exe --input "%INPUTFILE%" -l -o "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_WAV) > 0 then
    begin
      if not gudtOptions.bWAVCopyMetadata then
      begin
        sTmpOutputFile := StringReplaceAll(sInputFile, '.wav', '-stripped.wav');
        if sTmpOutputFile = sInputFile then
          sTmpOutputFile := sTmpOutputFile + '-stripped.wav';
        RunPlugin(AIndex, 'shntool (1/2)', sPluginsDirectory + 'shntool.exe strip -q -O always -d "' + ExtractFileDir(sInputFile) + '" "%INPUTFILE%"', sInputFile, '', 0, 0);
        if (FileSizeOrZero(sTmpOutputFile) > 0) and (FileSizeOrZero(sTmpOutputFile) < FileSizeOrZero(sInputFile)) then
          CopyFileData(sTmpOutputFile, sInputFile);
        if not gudtOptions.bDebug then
          SysUtils.DeleteFile(sTmpOutputFile);
        if gudtOptions.bWAVStripSilence then
        begin
          sTmpOutputFile := StringReplaceAll(sInputFile, '.wav', '-trimmed.wav');
          if sTmpOutputFile = sInputFile then
            sTmpOutputFile := sTmpOutputFile + '-trimmed.wav';
          RunPlugin(AIndex, 'shntool (2/2)', sPluginsDirectory + 'shntool.exe trim -q -O always -d "' + ExtractFileDir(sInputFile) + '" "%INPUTFILE%"', sInputFile, '', 0, 0);
          if (FileSizeOrZero(sTmpOutputFile) > 0) and (FileSizeOrZero(sTmpOutputFile) < FileSizeOrZero(sInputFile)) then
            CopyFileData(sTmpOutputFile, sInputFile);
          if not gudtOptions.bDebug then
            SysUtils.DeleteFile(sTmpOutputFile);
        end;
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_XML) > 0 then
    begin
      if gudtOptions.bXMLEnableLeanify then
      begin
        sFlags := '';
        if gudtOptions.iLeanifyIterations <> -1 then
          iLevel := gudtOptions.iLeanifyIterations
        else
          iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'Leanify (1/2)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
        RunPlugin(AIndex, 'Minify (2/2)', sPluginsDirectory + 'minify.exe "%INPUTFILE%" --output "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_WEBP) > 0 then
    begin
      sFlags := '';
      iLevel := min(gudtOptions.iLevel * 4 div 9, 4);
      sFlags := sFlags + '-s' + IntToStr(iLevel) + ' ';
      if gudtOptions.bWEBPAllowLossy then
        sFlags := sFlags + '-quality=95 -webp '
      else
        sFlags := sFlags + '-lossless ';
      RunPlugin(AIndex, 'pingo (1/2)', sPluginsDirectory + 'pingo.exe ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if gudtOptions.bWEBPAllowLossy then
      begin
        iLevel := min(gudtOptions.iLevel * 6 div 9, 6);
        sFlags := sFlags + '-m ' + IntToStr(iLevel) + ' ';
      end
      else
      begin
        iLevel := min(gudtOptions.iLevel * 9 div 9, 9);
        sFlags := sFlags + '-z ' + IntToStr(iLevel) + ' -lossless ';
      end;
      RunPlugin(AIndex, 'cwebp (2/2)', sPluginsDirectory + 'cwebp.exe -mt -quiet ' + sFlags + '"%INPUTFILE%" -o "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_ZIP) > 0 then
    begin
      bIsEXESFX := IsEXESFX(sInputFile);
      sFlags := '';
      if gudtOptions.bZIPCopyMetadata then
        sFlags := sFlags + '--keep-exif ';
      if gudtOptions.iLeanifyIterations <> -1 then
        iLevel := gudtOptions.iLeanifyIterations
      else
        iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
      sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
      sFlags := sFlags + '--zip-deflate ';
      if not gudtOptions.bZIPRecurse then
        sFlags := sFlags + '-d 1 ';
      if gudtOptions.bJPEGCopyMetadata then
        sFlags := sFlags + '--keep-exif --keep-icc --jpeg-keep-all ';
      if gudtOptions.bJPEGUseArithmeticEncoding then
        sFlags := sFlags + '--jpeg-arithmetic ';
      RunPlugin(AIndex, 'Leanify (1/6)', sPluginsDirectory + 'leanify.exe -q -p ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      sFlags := '';
      if not gudtOptions.bZIPCopyMetadata then
        sFlags := sFlags + '-strip ';
      if (not gudtOptions.bZIPRecurse) and (PosEx(sExtensionByContent, ' .zip ') > 0) then
        sFlags := sFlags + '--disable-png --disable-jpg ';
      iLevel := min(gudtOptions.iLevel * 8 div 9, 8) + 1;
      if iLevel = 9 then
        iLevel := 90032;
      sFlags := sFlags + '-' + IntToStr(iLevel) + ' ';
      RunPlugin(AIndex, 'ECT (2/6)', sPluginsDirectory + 'ECT.exe -quiet --mt-deflate --mt-file -zip ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      if not bIsEXESFX then
      begin
        sFlags := '';
        iLevel := ((gudtOptions.iLevel * gudtOptions.iLevel * gudtOptions.iLevel) div 25) + 1;
        sFlags := sFlags + '-i ' + IntToStr(iLevel) + ' ';
        RunPlugin(AIndex, 'advzip (3/6)', sPluginsDirectory + 'advzip.exe -z -q -4 ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      end;
      sFlags := '';
      if gudtOptions.bZIPCopyMetadata then
        sFlags := sFlags + '/c ';
      RunPlugin(AIndex, 'DeflOpt (4/6)', sPluginsDirectory + 'deflopt.exe /a /b /s ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'defluff (5/6)', sPluginsDirectory + 'defluff.bat "%INPUTFILE%" "%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      RunPlugin(AIndex, 'DeflOpt (6/6)', sPluginsDirectory + 'deflopt.exe /a /b /s ' + sFlags + '"%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_7Z) > 0 then
    begin
      if gudtOptions.iLevel > 7 then
        RunPlugin(AIndex, 'm7zRepacker (1/1)', sPluginsDirectory + 'm7zrepacker.exe -m1 -d1024 -mem2048 "%TMPINPUTFILE%"', sInputFile, '', 0, 0);
    end;
    if PosEx(sExtensionByContent, KS_EXTENSION_MISC) > 0 then
    begin
      if not gudtOptions.bMiscDisable then
      begin
        sFlags := '';
        if not gudtOptions.bMiscCopyMetadata then
          sFlags := sFlags + '-strip ';
        RunPlugin(AIndex, 'ImageMagick (1/1)', sPluginsDirectory + 'magick.exe convert "%INPUTFILE%" -quiet ' + sFlags + '"%TMPOUTPUTFILE%"', sInputFile, '', 0, 0);
      end;
    end;
end;

function TOptimizerService.RunPlugin(const AIndex: Integer; const AStatus, ACommand, AInputFile, AOutputFile: string; const AErrorMin, AErrorMax: Integer): Boolean;
var
  Arguments, Command, Mask, ToolName: string;
  Masks: TStringList;
  Index, Separator: SizeInt;
  UseInPlace: Boolean;
begin
  Result := False;
  if IsCancelled or not StartsText(IncludeTrailingPathDelimiter(FPluginDirectory), ACommand) then
    Exit;
  Command := Copy(ACommand, Length(IncludeTrailingPathDelimiter(FPluginDirectory)) + 1, MaxInt);
  Separator := Pos(' ', Command);
  if Separator = 0 then
  begin
    ToolName := Command;
    Arguments := '';
  end
  else
  begin
    ToolName := Copy(Command, 1, Separator - 1);
    Arguments := Copy(Command, Separator + 1, MaxInt);
  end;
  Mask := FConfiguration.GetText('General', 'DisablePluginMask');
  if Mask <> '' then
  begin
    Masks := TStringList.Create;
    try
      Masks.StrictDelimiter := True;
      Masks.Delimiter := ',';
      Masks.DelimitedText := Mask;
      for Index := 0 to Masks.Count - 1 do
        if (Trim(Masks[Index]) <> '') and (Pos(UpperCase(Trim(Masks[Index])), UpperCase(ACommand)) > 0) then
          Exit;
    finally
      Masks.Free;
    end;
  end;
  UseInPlace := Pos('%TMPINPUTFILE%', Arguments) > 0;
  Arguments := StringReplaceAll(Arguments, '%TMPINPUTFILE%', '%INPUT%');
  Arguments := StringReplaceAll(Arguments, '%INPUTFILE%', '%INPUT%');
  Arguments := StringReplaceAll(Arguments, '%TMPOUTPUTFILE%', '%OUTPUT%');
  if (Pos('%INPUT%', Arguments) = 0) and (Pos('%OUTPUT%', Arguments) = 0) then
    Exit;
  Result := RunTool(AIndex, AStatus, ToolName, Arguments, AInputFile, UseInPlace, AErrorMin, AErrorMax);
end;

function TOptimizerService.RunRedirectedProcess(const AExecutable, AArguments, AInputFile, AOutputFile: string; const AAppendOutput: Boolean): Integer;
var
  CommandLine: UnicodeString;
  ErrorHandle, InputHandle, OutputHandle: THandle;
  ProcessInfo: TProcessInformation;
  Security: TSecurityAttributes;
  Startup: Windows.TStartupInfoW;
  WaitResult: DWORD;
begin
  Result := -1;
  if not FileExists(AExecutable) then
    Exit;
  FillChar(Security, SizeOf(Security), 0);
  Security.nLength := SizeOf(Security);
  Security.bInheritHandle := True;
  if AInputFile <> '' then
    InputHandle := CreateFileW(PWideChar(UnicodeString(AInputFile)), GENERIC_READ, FILE_SHARE_READ, @Security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)
  else
    InputHandle := CreateFileW('NUL', GENERIC_READ, FILE_SHARE_READ, @Security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if InputHandle = INVALID_HANDLE_VALUE then
    Exit;
  try
    if AOutputFile <> '' then
      OutputHandle := CreateFileW(PWideChar(UnicodeString(AOutputFile)), GENERIC_WRITE, FILE_SHARE_READ, @Security, IfThen(AAppendOutput, OPEN_ALWAYS, CREATE_ALWAYS), FILE_ATTRIBUTE_NORMAL, 0)
    else
      OutputHandle := CreateFileW('NUL', GENERIC_WRITE, FILE_SHARE_READ, @Security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if OutputHandle = INVALID_HANDLE_VALUE then
      Exit;
    try
      ErrorHandle := CreateFileW('NUL', GENERIC_WRITE, FILE_SHARE_READ, @Security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
      if ErrorHandle = INVALID_HANDLE_VALUE then
        Exit;
      try
      if AAppendOutput then
        SetFilePointer(OutputHandle, 0, nil, FILE_END);
      FillChar(Startup, SizeOf(Startup), 0);
      Startup.cb := SizeOf(Startup);
      Startup.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
      Startup.wShowWindow := SW_HIDE;
      Startup.hStdInput := InputHandle;
      Startup.hStdOutput := OutputHandle;
      Startup.hStdError := ErrorHandle;
      FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);
      CommandLine := '"' + UnicodeString(AExecutable) + '" ' + UnicodeString(AArguments);
      if not CreateProcessW(nil, PWideChar(CommandLine), nil, nil, True, CREATE_NO_WINDOW or DWORD(FConfiguration.GetInteger('General', 'ProcessPriority')), nil, PWideChar(UnicodeString(FPluginDirectory)), Startup, ProcessInfo) then
        Exit;
      try
        repeat
          WaitResult := WaitForSingleObject(ProcessInfo.hProcess, 100);
          if IsCancelled then
            TerminateProcess(ProcessInfo.hProcess, 1);
        until WaitResult <> WAIT_TIMEOUT;
        GetExitCodeProcess(ProcessInfo.hProcess, DWORD(Result));
      finally
        CloseHandle(ProcessInfo.hThread);
        CloseHandle(ProcessInfo.hProcess);
      end;
      finally
        CloseHandle(ErrorHandle);
      end;
    finally
      CloseHandle(OutputHandle);
    end;
  finally
    CloseHandle(InputHandle);
  end;
end;

function TOptimizerService.RunBatchPlugin(const ATool, AInputFile, AOutputFile: string): Integer;
var
  ProgramPath, TemporaryFile: string;
  Stream: TFileStream;
  Header: AnsiString;
begin
  Result := -1;
  if SameText(ATool, 'defluff.bat') or SameText(ATool, 'jsmin.bat') then
  begin
    if SameText(ATool, 'defluff.bat') then
      ProgramPath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'defluff.exe'
    else
      ProgramPath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'jsmin.exe';
    Exit(RunRedirectedProcess(ProgramPath, '', AInputFile, AOutputFile));
  end;
  if SameText(ATool, 'libdeflate.bat') then
  begin
    ProgramPath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'gzip.exe';
    TemporaryFile := NewTempPath(GetTempDir(False));
    try
      Result := RunRedirectedProcess(ProgramPath, '-cd "' + AInputFile + '"', '', TemporaryFile);
      if Result = 0 then
        Result := RunRedirectedProcess(ProgramPath, '-12 -f', TemporaryFile, AOutputFile);
    finally
      SysUtils.DeleteFile(TemporaryFile);
    end;
    Exit;
  end;
  if SameText(ATool, 'sqlite.bat') then
  begin
    ProgramPath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'sqlite3.exe';
    TemporaryFile := NewTempPath(GetTempDir(False)) + '.sql';
    Stream := TFileStream.Create(TemporaryFile, fmCreate);
    try
      Header := 'PRAGMA optimize(0xfffe);' + LineEnding;
      Stream.WriteBuffer(Header[1], Length(Header));
    finally
      Stream.Free;
    end;
    try
      Result := RunRedirectedProcess(ProgramPath, '"' + AInputFile + '" .dump', '', TemporaryFile, True);
      if Result = 0 then
        Result := RunRedirectedProcess(ProgramPath, '"' + AOutputFile + '"', TemporaryFile, '');
    finally
      SysUtils.DeleteFile(TemporaryFile);
    end;
  end;
end;

function TOptimizerService.RunTool(const AIndex: Integer; const AStatus, ATool, AArguments, AWorkingFile: string;
  const AInPlace: Boolean; const AErrorMin, AErrorMax: Integer): Boolean;
var
  Candidate, CommandLine, ExePath: string;
  ExitCode: Integer;
  OldSize, NewSize: Int64;
  StartedAt: TDateTime;
begin
  Result := False;
  if IsCancelled then
    Exit;
  ExePath := IncludeTrailingPathDelimiter(FPluginDirectory) + ATool;
  if SameText(ATool, 'defluff.bat') then
    ExePath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'defluff.exe'
  else if SameText(ATool, 'jsmin.bat') then
    ExePath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'jsmin.exe'
  else if SameText(ATool, 'libdeflate.bat') then
    ExePath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'gzip.exe'
  else if SameText(ATool, 'sqlite.bat') then
    ExePath := IncludeTrailingPathDelimiter(FPluginDirectory) + 'sqlite3.exe';
  if not FileExists(ExePath) then
    Exit;
  Candidate := NewTempPath(ExtractFileDir(AWorkingFile)) + ExtractFileExt(AWorkingFile);
  OldSize := FileSizeOrZero(AWorkingFile);
  if AInPlace and not CopyFileData(AWorkingFile, Candidate) then
    Exit;
  CommandLine := StringReplace(AArguments, '%INPUT%', '"' + IfThen(AInPlace, Candidate, AWorkingFile) + '"', [rfReplaceAll]);
  CommandLine := StringReplace(CommandLine, '%OUTPUT%', '"' + Candidate + '"', [rfReplaceAll]);
  SetResult(AIndex, fsRunning, OldSize, AStatus);
  StartedAt := Now;
  ExitCode := -1;
  if SameText(ExtractFileExt(ATool), '.bat') then
    ExitCode := RunBatchPlugin(ATool, IfThen(AInPlace, Candidate, AWorkingFile), Candidate)
  else
    ExitCode := RunRedirectedProcess(ExePath, CommandLine, '', '');
  WritePluginLog(ExePath + ' ' + CommandLine, AStatus, ExitCode, OldSize, FileSizeOrZero(Candidate), StartedAt);
  if (ExitCode < AErrorMin) or (ExitCode > AErrorMax) then
  begin
    FLock.Enter;
    try
      FItems[AIndex].LastPluginError := AStatus + ': exit code ' + IntToStr(ExitCode);
    finally
      FLock.Leave;
    end;
  end;
  if ExitCode >= 0 then
  begin
    FLock.Enter;
    try
      Inc(FItems[AIndex].PluginRuns);
    finally
      FLock.Leave;
    end;
  end;
  try
    NewSize := FileSizeOrZero(Candidate);
    if (ExitCode >= AErrorMin) and (ExitCode <= AErrorMax) and (NewSize >= 8) and (NewSize < OldSize) then
    begin
      Result := CopyFileData(Candidate, AWorkingFile);
      if Result then
        SetResult(AIndex, fsRunning, NewSize, AStatus);
    end;
  finally
    if not FConfiguration.GetBoolean('General', 'Debug') then
      SysUtils.DeleteFile(Candidate);
  end;
end;

end.
