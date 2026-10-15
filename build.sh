#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="Mac-AutoTyper.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target x86_64-apple-macosx13.0 -o "$APP/Contents/MacOS/Mac-AutoTyper" src/*.swift -framework AppKit -framework ApplicationServices -framework Carbon
cp Info.plist "$APP/Contents/Info.plist"
cp resources/icon.icns "$APP/Contents/Resources/icon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP"
codesign --verify --verbose=2 "$APP"
file "$APP/Contents/MacOS/Mac-AutoTyper"
