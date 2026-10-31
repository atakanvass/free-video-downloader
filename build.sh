#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p "build/Free Video Downloader.app/Contents/MacOS"
cp Info.plist "build/Free Video Downloader.app/Contents/Info.plist"
swiftc Sources/Kaydet.swift -o "build/Free Video Downloader.app/Contents/MacOS/Free Video Downloader"
printf 'App ready: build/Free Video Downloader.app\n'
