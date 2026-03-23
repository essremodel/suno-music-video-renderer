#!/usr/bin/env bash
# render_single.sh — Render one MP3 into a YouTube-style 1920×1080 music video.
#
# Usage:
#   render_single.sh [OPTIONS] "Song Title – Artist [hash].mp3"
#
# Options:
#   --output-dir DIR   Directory to write the .mp4 (default: ./rendered)
#   -h, --help         Show this help message
#
# Filename format expected:
#   "Title – Artist [hexhash].mp3"  (em-dash U+2013, not a regular hyphen)
#   If no " – " separator is found the whole name is used as the title.
#
# Pipeline:
#   1. ffmpeg      — extract embedded MJPEG album art (attached_pic stream)
#   2. ImageMagick — build 1920×1080 composite: blurred bg + sharp centered art
#   3. add_text.py — overlay title + artist text via Pillow (avoids ffmpeg drawtext)
#   4. ffmpeg      — encode static frame + audio → H.264/AAC .mp4
#
# Environment (passed through to add_text.py):
#   TITLE_FONT    Path to title font  (default: /Library/Fonts/Arial.ttf)
#   ARTIST_FONT   Path to artist font (default: /Library/Fonts/Arial.ttf)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
}

# ── Argument parsing ───────────────────────────────────────────────────────────
OUTPUT_DIR="./rendered"
INPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        -*)           echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)            INPUT="$1"; shift ;;
    esac
done

if [[ -z "$INPUT" ]]; then
    echo "Error: no input file specified." >&2
    usage >&2
    exit 1
fi

# ── Parse title and artist from filename: "Title – Artist [hash].mp3" ─────────
BASENAME="$(basename "$INPUT" .mp3)"
STRIPPED="${BASENAME% \[*\]}"

if [[ "$STRIPPED" == *" – "* ]]; then          # em-dash (U+2013)
    TITLE="${STRIPPED%% – *}"
    ARTIST="${STRIPPED##* – }"
elif [[ "$STRIPPED" == *" - "* ]]; then         # plain hyphen fallback
    TITLE="${STRIPPED%% - *}"
    ARTIST="${STRIPPED##* - }"
else
    TITLE="$STRIPPED"
    ARTIST="Unknown Artist"
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT="${OUTPUT_DIR}/${BASENAME}.mp4"

echo "──────────────────────────────────────────────"
echo "  Input:  $INPUT"
echo "  Title:  $TITLE"
echo "  Artist: $ARTIST"
echo "  Output: $OUTPUT"
echo "──────────────────────────────────────────────"

# ── Step 1: Extract embedded album art ────────────────────────────────────────
# Suno MP3s embed cover art as an MJPEG attached_pic (stream index 1).
# -map 0:v:0 selects the first video stream (the cover), -c:v copy avoids
# re-encoding. Fall back to -frames:v 1 decode if copy fails.
COVER="/tmp/cover_$$.jpg"
ffmpeg -y -i "$INPUT" -map 0:v:0 -c:v copy "$COVER" 2>/dev/null \
    || ffmpeg -y -i "$INPUT" -map 0:v:0 -frames:v 1 "$COVER" 2>/dev/null \
    || { echo "ERROR: No embedded album art found in '$INPUT'" >&2; exit 1; }

echo "✓ Extracted cover art → $COVER"

# ── Step 2: Build composite frame with ImageMagick ────────────────────────────
# Background: cover scaled to fill 1920×1080, heavy gaussian blur, slightly darkened.
# Foreground: sharp cover art resized to 650px tall, centered (shifted up 40px).
ART="/tmp/art_$$.png"
FRAME_NOTEXT="/tmp/frame_notext_$$.png"

magick "$COVER" -resize x650 "$ART"
ART_W=$(magick identify -format "%w" "$ART")
ART_H=$(magick identify -format "%h" "$ART")
ART_X=$(( (1920 - ART_W) / 2 ))
ART_Y=$(( (1080 - ART_H) / 2 - 40 ))

magick "$COVER" \
    -resize 1920x1080^ -gravity Center -extent 1920x1080 \
    -blur 0x30 \
    -modulate 92 \
    \( "$ART" \) -gravity NorthWest -geometry "+${ART_X}+${ART_Y}" -composite \
    "$FRAME_NOTEXT"

echo "✓ Composite frame (no text) → $FRAME_NOTEXT"

# ── Step 3: Overlay text with Pillow ──────────────────────────────────────────
# add_text.py accepts title/artist as argv — no shell escaping needed for
# apostrophes, em-dashes, parentheses, or other special characters.
FRAME="/tmp/frame_$$.png"
python3 "$SCRIPT_DIR/add_text.py" "$FRAME_NOTEXT" "$FRAME" "$TITLE" "$ARTIST"

echo "✓ Text overlay → $FRAME"

# ── Step 4: Encode video ───────────────────────────────────────────────────────
# Static 30fps frame + original audio stream → H.264/AAC mp4.
# -shortest stops encoding when the audio ends.
ffmpeg -y \
    -loop 1 -framerate 30 -i "$FRAME" \
    -i "$INPUT" \
    -map 0:v -map 1:a \
    -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -movflags +faststart \
    -shortest \
    "$OUTPUT"

# ── Cleanup ────────────────────────────────────────────────────────────────────
rm -f "$COVER" "$ART" "$FRAME_NOTEXT" "$FRAME"

echo ""
echo "✅ Done! → $OUTPUT"
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT" | cut -d. -f1)
RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT")
echo "   Duration: ${DURATION}s   Resolution: ${RES}"
ls -lh "$OUTPUT"
