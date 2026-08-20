#!/usr/bin/env bash
set -euo pipefail

# Lazarus 4.8 LCL의 ICO 로더는 기본 설치 상태에서 PNG-compressed ICO 엔트리를
# 256x256 크기일 때만 PNG로 검사한다. 그래서 16/32/48/64/128 같은 non-256 PNG
# 엔트리는 DIB/BMP로 잘못 읽히고, 앱 아이콘 로딩 중 "Bitmap with unknown
# compression" 같은 예외가 날 수 있다.
#
# 이 스크립트는 LCL 소스의 좁은 한 지점만 패치한다:
#   lcl/include/icon.inc
#
# 실행 전:
#   1. Lazarus IDE를 종료한다.
#   2. Git Bash에서 실행한다.
#   3. 설치 경로가 기본값이 아니면 첫 번째 인자 또는 LAZARUS_DIR로 넘긴다.
#
# 실행 예:
#   ./script/patch-icon-inc.sh
#   LAZARUS_DIR=/e/lazarus ./script/patch-icon-inc.sh
#   ./script/patch-icon-inc.sh /e/lazarus
#
# 실행 후:
#   1. Lazarus IDE에서 Tools > Build Lazarus with Profile: Normal IDE를 실행한다.
#   2. 또는 Git Bash에서 아래 명령으로 IDE/LCL을 다시 빌드한다.
#      cd /e/lazarus
#      PATH="/e/lazarus/fpc/3.2.2/bin/x86_64-win64:/e/lazarus:$PATH" make bigide
#   3. TIcon.LoadFromFile('resource/main.ico') 또는 프로젝트 lazbuild로 검증한다.

LAZARUS_DIR="${1:-${LAZARUS_DIR:-/e/lazarus}}"
ICON_INC="$LAZARUS_DIR/lcl/include/icon.inc"
BACKUP="$ICON_INC.before-ico-png-fix"

if [[ ! -f "$ICON_INC" ]]; then
  echo "오류: icon.inc를 찾을 수 없습니다: $ICON_INC" >&2
  exit 1
fi

if ! command -v patch >/dev/null 2>&1; then
  echo "오류: 이 스크립트는 Git Bash의 patch가 필요합니다." >&2
  exit 1
fi

if ! grep -q 'IconDir\[n\]\.bWidth = 0' "$ICON_INC"; then
  echo "이미 패치된 것으로 보입니다: $ICON_INC"
  echo "다음 단계: Lazarus IDE/LCL을 다시 빌드했는지 확인하세요."
  exit 0
fi

if [[ ! -f "$BACKUP" ]]; then
  cp -p "$ICON_INC" "$BACKUP"
  echo "백업 생성: $BACKUP"
else
  echo "기존 백업 유지: $BACKUP"
fi

(
  cd "$LAZARUS_DIR"
  patch -p0 <<'PATCH'
--- lcl/include/icon.inc
+++ lcl/include/icon.inc
@@ -877,23 +877,17 @@ begin
       AStream.Seek(StreamStart + IconDir[n].dwImageOffset, soBeginning);
       
       ImgReader := nil;
-      if (IconDir[n].bWidth = 0) or (IconDir[n].bHeight = 0)
+      // PNG or DIB image
+      // don't use PNGReader.CheckContents(AStream) since it uses internally
+      // an exception for checking, which is not "nice" when debugging.
+      AStream.Read(PNGSig, SizeOf(PNGSig));
+      AStream.Seek(StreamStart + IconDir[n].dwImageOffset, soBeginning);
+
+      if QWord(PNGComn.Signature) = QWord(PNGSig)
       then begin
-        // PNG or DIB image
-        // Vista icons are PNG in this case, but there exist also "old style" icons
-        // with DIB image
-        
-        // don't use PNGReader.CheckContents(AStream) since it uses internally
-        // an exception for checking, which is not "nice" when debugging.
-        AStream.Read(PNGSig, SizeOf(PNGSig));
-        AStream.Seek(StreamStart + IconDir[n].dwImageOffset, soBeginning);
-
-        if QWord(PNGComn.Signature) = QWord(PNGSig)
-        then begin
-          if PNGReader = nil
-          then PNGReader := TLazReaderPNG.Create;
-          ImgReader := PNGReader;
-        end;
+        if PNGReader = nil
+        then PNGReader := TLazReaderPNG.Create;
+        ImgReader := PNGReader;
       end;
       
       if ImgReader = nil
PATCH
)

if grep -q 'IconDir\[n\]\.bWidth = 0' "$ICON_INC"; then
  echo "오류: 패치가 적용되지 않았습니다. Lazarus 버전의 icon.inc 문맥이 달라졌을 수 있습니다." >&2
  echo "복구가 필요하면 다음 파일을 되돌리세요: $BACKUP" >&2
  exit 1
fi

echo "패치 완료: $ICON_INC"
echo "다음 단계: Lazarus IDE/LCL을 다시 빌드한 뒤 프로젝트를 lazbuild로 확인하세요."
