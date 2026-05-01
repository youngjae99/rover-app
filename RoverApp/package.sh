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

# Optional: sign the DMG itself + notarize + staple. Skipped entirely
# when CODESIGN_IDENTITY is unset (local dev) or set to "-" (ad-hoc).
# The notary block additionally requires NOTARY_KEY_PATH / NOTARY_KEY_ID
# / NOTARY_ISSUER_ID — without them the DMG ships signed but un-stapled
# and Gatekeeper will still complain on first launch.
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    echo "→ codesign DMG"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_NAME"

    if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
        echo "→ notarytool submit (this can take several minutes)"
        xcrun notarytool submit "$DMG_NAME" \
            --key "$NOTARY_KEY_PATH" \
            --key-id "$NOTARY_KEY_ID" \
            --issuer "$NOTARY_ISSUER_ID" \
            --wait
        echo "→ stapling notarization ticket"
        xcrun stapler staple "$DMG_NAME"
        # Final Gatekeeper sanity check — proves the DMG passes spctl
        # the way an end user's machine will.
        spctl -a -t open --context context:primary-signature -v "$DMG_NAME" || true
    else
        echo "  (skipping notarization: NOTARY_KEY_* env vars not set)"
    fi
fi

SIZE=$(du -h "$DMG_NAME" | awk '{print $1}')
echo "✓ $DMG_NAME ($SIZE)"
echo "  Drop on a GitHub Release with:"
echo "    gh release create v<version> $DMG_NAME --title v<version> --notes ..."
