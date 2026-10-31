#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/Kaydet.app/Contents/MacOS
cp Info.plist build/Kaydet.app/Contents/Info.plist
swiftc Sources/Kaydet.swift -o build/Kaydet.app/Contents/MacOS/Kaydet
printf 'Uygulama hazır: build/Kaydet.app\n'
