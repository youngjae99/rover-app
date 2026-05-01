#!/usr/bin/env bash
# Build Rover.icns from the idle sprite. Requires `magick` (ImageMagick) and
# `iconutil` (Apple, ships with Command Line Tools).

set -euo pipefail
cd "$(dirname "$0")"

SRC="../rover/Resources/_1Idle/001.png"
ICONSET="Rover.iconset"
ICNS="Rover.icns"

if [[ ! -f "$SRC" ]]; then
    echo "✗ source sprite not found: $SRC" >&2
    exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
    echo "✗ ImageMagick (magick) not found. Install with: brew install imagemagick" >&2
    exit 1
fi

TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

echo "→ building 1024 master"

# 1. Pale-blue gradient. We pre-pin sRGB + TrueColorAlpha because
#    ImageMagick auto-detects "grayscale" when the color delta per channel
#    is small, which silently desaturates the whole pipeline downstream.
magick -size 1024x1024 gradient:'#E5EFFB-#88B5E0' \
       -colorspace sRGB -type TrueColorAlpha \
       "$TMP/grad.png"

# 2. Rounded-corner alpha mask, then knock out the corners on the gradient.
magick "$TMP/grad.png" \
       \( -size 1024x1024 xc:none -fill white \
          -draw "roundrectangle 0,0 1023,1023 220,220" \) \
       -compose copy_opacity -composite \
       -colorspace sRGB -type TrueColorAlpha \
       "$TMP/bg.png"

# 3. Upscale Rover.
magick "$SRC" -filter lanczos -resize 760x760 \
       -colorspace sRGB -type TrueColorAlpha \
       "$TMP/rover.png"

# 4. Drop a soft shadow under Rover.
magick "$TMP/rover.png" \
       \( +clone -background black -shadow 35x10+0+12 \) +swap \
       -background none -layers merge +repage \
       -colorspace sRGB -type TrueColorAlpha \
       "$TMP/rover-shadow.png"

# 5. Composite Rover onto the squircle, biased a touch upward so the
#    sprite reads as visually centered.
magick "$TMP/bg.png" "$TMP/rover-shadow.png" \
       -gravity center -geometry +0-30 \
       -compose over -composite \
       -colorspace sRGB -type TrueColorAlpha \
       "$TMP/master.png"

echo "→ slicing into iconset"
rm -rf "$ICONSET" "$ICNS"
mkdir -p "$ICONSET"

for s in 16 32 128 256 512; do
    s2=$((s * 2))
    magick "$TMP/master.png" -resize ${s}x${s}   "$ICONSET/icon_${s}x${s}.png"
    magick "$TMP/master.png" -resize ${s2}x${s2} "$ICONSET/icon_${s}x${s}@2x.png"
done

echo "→ iconutil -c icns"
iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

SIZE=$(du -h "$ICNS" | awk '{print $1}')
echo "✓ $ICNS ($SIZE)"
