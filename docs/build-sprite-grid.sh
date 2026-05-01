#!/usr/bin/env bash
# Build docs/rover-states-grid.png — a 4x3 grid of 12 representative
# Rover states, used in the README. Source frames come from the
# original Microsoft sprite sheets in rover/Resources/.
#
# Output: docs/rover-states-grid.png (transparent background, ~960x720,
# labelled per cell).
#
# Re-run whenever the state list changes:
#     ./docs/build-sprite-grid.sh

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="docs/rover-states-grid.png"
SRC="rover/Resources"

# 12 unique states. Each entry is `dir:frame:label`. The frame index
# is chosen mid-animation so the pose is distinctive — picking 001 for
# every state would just give you the same idle frame twelve times,
# because most animations start from a neutral rest pose.
STATES=(
  "_1Idle:003:idle"
  "Speak:008:speak"
  "Reading:012:reading"
  "Eat:040:eat"
  "Sleep:005:sleep"
  "Tired:008:tired"
  "Haf:004:haf"
  "Lick:010:lick"
  "Ashamed:014:ashamed"
  "GetAttention:006:attention"
  "Come:010:come"
  "Exit:020:exit"
)

if ! command -v magick >/dev/null 2>&1; then
    echo "✗ ImageMagick (magick) not found. Install with: brew install imagemagick" >&2
    exit 1
fi

TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

# Each cell: 240x240 — the 80x80 source upscaled 3x with nearest-neighbour
# (preserves the chunky XP pixel look) plus a labelled caption strip.
for entry in "${STATES[@]}"; do
    IFS=':' read -r dir frame label <<<"$entry"
    src="$SRC/$dir/${frame}.png"
    if [[ ! -f "$src" ]]; then
        echo "✗ missing source frame: $src" >&2
        exit 1
    fi
    # ImageMagick's font lookup via fontconfig fails on stock macOS — pass
    # the .ttc path directly. SF / Helvetica are guaranteed to be present.
    FONT="/System/Library/Fonts/Helvetica.ttc"
    magick "$src" \
        -filter point -resize 240x240 \
        -background none -gravity center -extent 240x240 \
        \( -size 240x32 xc:none -gravity center \
           -font "$FONT" -pointsize 18 -fill "#444" \
           -annotate +0+0 "$label" \) \
        -append \
        "$TMP/cell_$label.png"
done

# 4 columns x 3 rows.
magick montage \
    "$TMP/cell_idle.png" \
    "$TMP/cell_speak.png" \
    "$TMP/cell_reading.png" \
    "$TMP/cell_eat.png" \
    "$TMP/cell_sleep.png" \
    "$TMP/cell_tired.png" \
    "$TMP/cell_haf.png" \
    "$TMP/cell_lick.png" \
    "$TMP/cell_ashamed.png" \
    "$TMP/cell_attention.png" \
    "$TMP/cell_come.png" \
    "$TMP/cell_exit.png" \
    -font "/System/Library/Fonts/Helvetica.ttc" \
    -tile 4x3 \
    -geometry +12+12 \
    -background none \
    -label "" \
    "$OUT"

SIZE=$(du -h "$OUT" | awk '{print $1}')
echo "✓ $OUT ($SIZE)"
