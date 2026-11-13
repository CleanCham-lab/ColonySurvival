#!/bin/bash
# ============================================================
#  Colony Survival — 원클릭 빌드 (macOS에서 더블클릭)
#
#  결과물 (build/ 폴더):
#    mac/ColonySurvival.app   ← 더블클릭으로 실행되는 Mac 앱
#    mac/ColonySurvival.dmg   ← 배포용 디스크 이미지
#    windows/ColonySurvival.exe
#    web/  (itch.io 업로드용)
#
#  처음 한 번만 Godot 4.7.2와 내보내기 템플릿(약 1GB)을 자동으로 받습니다.
#  두 번째부터는 1분 안에 끝납니다.
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"
PROJ="$(pwd)"
VER="${GODOT_VERSION:-4.7.2}"
TAG="${VER}-stable"
TOOLS="$PROJ/.build_tools"
TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/${VER}.stable"
mkdir -p "$TOOLS" "$PROJ/build/mac" "$PROJ/build/windows" "$PROJ/build/web"
touch "$PROJ/build/.gdignore"   # 결과물 폴더는 Godot가 리소스로 읽지 않게

say() { printf "\n\033[1;36m[Colony Survival]\033[0m %s\n" "$1"; }

download() {  # $1 = 파일명, $2 = 저장 경로
  for base in "https://github.com/godotengine/godot-builds/releases/download/$TAG" \
              "https://github.com/godotengine/godot/releases/download/$TAG"; do
    if curl -L --fail --progress-bar -o "$2" "$base/$1"; then return 0; fi
  done
  echo "다운로드 실패: $1  (인터넷 연결 또는 버전 $VER 확인)"; exit 1
}

# 1) Godot 찾기 (이미 설치돼 있으면 그대로 사용)
GODOT=""
for cand in "/Applications/Godot.app/Contents/MacOS/Godot" "$TOOLS/Godot.app/Contents/MacOS/Godot"; do
  if [ -x "$cand" ] && "$cand" --version 2>/dev/null | grep -q "^${VER}\.stable"; then GODOT="$cand"; break; fi
done
if [ -z "$GODOT" ]; then
  say "Godot $VER 내려받는 중 (약 70MB, 처음 한 번)"
  download "Godot_v${TAG}_macos.universal.zip" "$TOOLS/godot.zip"
  rm -rf "$TOOLS/Godot.app"
  ditto -x -k "$TOOLS/godot.zip" "$TOOLS"
  rm -f "$TOOLS/godot.zip"
  GODOT="$TOOLS/Godot.app/Contents/MacOS/Godot"
fi
say "Godot: $GODOT"

# 2) 내보내기 템플릿
if [ ! -f "$TPL_DIR/macos.zip" ]; then
  say "내보내기 템플릿 내려받는 중 (약 1GB, 처음 한 번 — 몇 분 걸립니다)"
  download "Godot_v${TAG}_export_templates.tpz" "$TOOLS/templates.tpz"
  mkdir -p "$TPL_DIR"
  unzip -o -j -q "$TOOLS/templates.tpz" "templates/*" -d "$TPL_DIR"
  rm -f "$TOOLS/templates.tpz"
fi

# 3) 리소스 임포트 + 내보내기
say "리소스 준비 중"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

say "Mac 앱 만드는 중"
rm -rf "$PROJ/build/mac/ColonySurvival.app" "$PROJ/build/mac/ColonySurvival.zip"
"$GODOT" --headless --path "$PROJ" --export-release "macOS" "$PROJ/build/mac/ColonySurvival.zip"
ditto -x -k "$PROJ/build/mac/ColonySurvival.zip" "$PROJ/build/mac"
rm -f "$PROJ/build/mac/ColonySurvival.zip"
APP="$(ls -d "$PROJ"/build/mac/*.app | head -1)"
if [ "$APP" != "$PROJ/build/mac/ColonySurvival.app" ]; then mv "$APP" "$PROJ/build/mac/ColonySurvival.app"; fi
rm -f "$PROJ/build/mac/ColonySurvival.dmg"
hdiutil create -quiet -volname "Colony Survival" -srcfolder "$PROJ/build/mac/ColonySurvival.app" -ov -format UDZO "$PROJ/build/mac/ColonySurvival.dmg"

say "Windows 실행 파일 만드는 중"
"$GODOT" --headless --path "$PROJ" --export-release "Windows" "$PROJ/build/windows/ColonySurvival.exe" || say "Windows 내보내기 실패(건너뜀)"

say "웹 버전 만드는 중"
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/build/web/index.html" || say "웹 내보내기 실패(건너뜀)"

say "완료! build 폴더를 엽니다."
echo "  Mac  : build/mac/ColonySurvival.app  (배포는 ColonySurvival.dmg)"
echo "  Win  : build/windows/ColonySurvival.exe"
echo "  Web  : build/web/  (폴더째 zip → itch.io)"
open "$PROJ/build"
