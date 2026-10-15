#!/bin/bash
set -euo pipefail
export LC_ALL=C LANG=C

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

command -v swiftc >/dev/null || { echo "需要 Swift / Xcode Command Line Tools。" >&2; exit 1; }
command -v ditto >/dev/null || { echo "需要 macOS 的 ditto 工具。" >&2; exit 1; }
if [[ ! -f dist/windows/Windows-AutoTyper.exe ]]; then
  ./windows/build.sh
fi
mkdir -p dist/windows
if [[ ! -f dist/windows/LICENSE ]]; then
  cp LICENSE dist/windows/LICENSE
fi
WINDOWS_EXE_INFO="$(file dist/windows/Windows-AutoTyper.exe)"
[[ "$WINDOWS_EXE_INFO" == *"x86-64"* ]] || { echo "Windows 可执行文件不是 x64：$WINDOWS_EXE_INFO" >&2; exit 1; }

MAC_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
WINDOWS_VERSION="1.0.2"
RELEASE_DIR="$ROOT/dist/release"
mkdir -p "$RELEASE_DIR"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mac-autotyper-release.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

build_mac_archive() {
  local arch="$1"
  local label="$2"
  local app="$TMP_DIR/Mac-AutoTyper-$label.app"
  local stage="$TMP_DIR/Mac-AutoTyper-macOS-$label"
  local archive="$RELEASE_DIR/Mac-AutoTyper-macOS-$label.zip"
  local staged_archive="$TMP_DIR/Mac-AutoTyper-macOS-$label.zip"
  local binary="$app/Contents/MacOS/Mac-AutoTyper"

  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  swiftc -O -target "$arch-apple-macosx13.0" -o "$binary" \
    src/*.swift -framework AppKit -framework ApplicationServices -framework Carbon
  cp Info.plist "$app/Contents/Info.plist"
  cp resources/icon.icns "$app/Contents/Resources/icon.icns"
  printf 'APPL????' > "$app/Contents/PkgInfo"
  codesign --force --sign - "$app"
  codesign --verify --verbose=2 "$app"
  test "$(lipo -archs "$binary")" = "$arch"
  file "$binary"

  mkdir -p "$stage/docs"
  ditto "$app" "$stage/Mac-AutoTyper.app"
  cp README.md LICENSE THIRD-PARTY.md "$stage/"
  cp docs/使用教程.md "$stage/docs/使用教程.md"
  ditto -c -k --sequesterRsrc --keepParent "$stage" "$staged_archive"
  mv -f "$staged_archive" "$archive"
  shasum -a 256 "$archive" > "$archive.sha256"
  echo "已生成 $archive（macOS $MAC_VERSION，$arch）"
}

build_mac_archive x86_64 Intel-x86_64
build_mac_archive arm64 Apple-Silicon-arm64

WINDOWS_STAGE="$TMP_DIR/Windows-AutoTyper-win-x64"
WINDOWS_ARCHIVE="$RELEASE_DIR/Windows-AutoTyper-win-x64.zip"
WINDOWS_STAGED_ARCHIVE="$TMP_DIR/Windows-AutoTyper-win-x64.zip"
mkdir -p "$WINDOWS_STAGE"
  cp dist/windows/Windows-AutoTyper.exe dist/windows/LICENSE \
  windows/README-Windows.txt windows/install.cmd windows/install.ps1 \
  tests/quark-acceptance.html "$WINDOWS_STAGE/"
ditto -c -k --sequesterRsrc --keepParent "$WINDOWS_STAGE" "$WINDOWS_STAGED_ARCHIVE"
mv -f "$WINDOWS_STAGED_ARCHIVE" "$WINDOWS_ARCHIVE"
shasum -a 256 "$WINDOWS_ARCHIVE" > "$WINDOWS_ARCHIVE.sha256"
echo "已生成 $WINDOWS_ARCHIVE（Windows $WINDOWS_VERSION，x64）"

(cd "$RELEASE_DIR" && shasum -a 256 \
  Mac-AutoTyper-macOS-Intel-x86_64.zip \
  Mac-AutoTyper-macOS-Apple-Silicon-arm64.zip \
  Windows-AutoTyper-win-x64.zip > SHA256SUMS.txt)
echo "发布资产和校验清单位于 $RELEASE_DIR"
