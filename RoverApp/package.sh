#!/usr/bin/env bash
# Build a release-mode Rover.app and package it into Rover.dmg.
#
# We use `hdiutil` directly rather than `create-dmg` because the latter
# drives Finder via AppleScript to position icons and that is unreliable
# (Apple Events permission, Finder timeouts, etc.). The resulting DMG is
# unstyled but functional: drag Rover.app onto the Applications symlink.

set -euo pipefail
cd "$(dirname "$0")"

DMG_NAME="Rover.dmg"
APP_NAME="Rover.app"
VOL_NAME="Rover"
STAGING_DIR=".dmg-staging"

echo "→ release build"
CONFIG=release ./build.sh >/dev/null

if [[ ! -d "$APP_NAME" ]]; then
    echo "✗ $APP_NAME not found after build" >&2
    exit 1
fi

echo "→ staging $STAGING_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_NAME" "$STAGING_DIR/"
ln -sf /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_NAME"

echo "→ creating $DMG_NAME"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_NAME" \
    >/dev/null

rm -rf "$STAGING_DIR"

SIZE=$(du -h "$DMG_NAME" | awk '{print $1}')
echo "✓ $DMG_NAME ($SIZE)"
echo "  Drop on a GitHub Release with:"
echo "    gh release create v<version> $DMG_NAME --title v<version> --notes ..."
