#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
ASSETS_DIR="$PROJECT_DIR/Assets"
ICONSET_DIR="$PROJECT_DIR/.build/AppIcon.iconset"
MASTER_PNG="$ASSETS_DIR/AppIcon.png"

mkdir -p "$ICONSET_DIR"

xcrun swift "$SCRIPT_DIR/render-svg.swift" "$ASSETS_DIR/AppIcon.svg" "$MASTER_PNG" 1024

sips -z 16 16 "$MASTER_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$MASTER_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$MASTER_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$MASTER_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$MASTER_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$MASTER_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$MASTER_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$MASTER_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$MASTER_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$MASTER_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil --convert icns "$ICONSET_DIR" --output "$ASSETS_DIR/AppIcon.icns"
