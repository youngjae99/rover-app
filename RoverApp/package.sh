#!/usr/bin/env bash
# Build a release-mode Rover.app and package it into Rover.dmg using create-dmg.
# Requires `brew install create-dmg`.

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "✗ create-dmg not found. Install with:"
    echo "    brew install create-dmg"
    exit 1
fi

echo "→ release build"
CONFIG=release ./build.sh >/dev/null

if [[ ! -d "Rover.app" ]]; then
    echo "✗ Rover.app not found after build" >&2
    exit 1
fi

DMG_NAME="Rover.dmg"
rm -f "$DMG_NAME"

echo "→ creating $DMG_NAME"
create-dmg \
    --volname "Rover" \
    --window-pos 200 120 \
    --window-size 560 380 \
    --icon-size 100 \
    --icon "Rover.app" 140 180 \
    --hide-extension "Rover.app" \
    --app-drop-link 420 180 \
    --no-internet-enable \
    "$DMG_NAME" \
    "Rover.app" \
    >/dev/null

SIZE=$(du -h "$DMG_NAME" | awk '{print $1}')
echo "✓ $DMG_NAME ($SIZE)"
echo "  Upload to GitHub Releases or distribute directly."
