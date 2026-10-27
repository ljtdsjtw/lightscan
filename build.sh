#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/轻扫码.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build"
xcrun swiftc -O -target arm64-apple-macosx13.0 Sources/Scanner.swift Sources/main.swift -o "$APP/Contents/MacOS/LightScan"
cp Info.plist "$APP/Contents/Info.plist"
xcrun swift Sources/MakeIcon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier local.lightscan.app "$APP"
printf '已生成：%s\n' "$APP"
