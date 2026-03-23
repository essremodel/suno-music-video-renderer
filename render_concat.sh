#!/usr/bin/env bash
# render_concat.sh — Concatenate rendered .mp4 files into one full-album video.
#
# Usage:
#   render_concat.sh [OPTIONS] [INPUT_DIR]
#
# Arguments:
#   INPUT_DIR   Directory of .mp4 files to concatenate (default: ./rendered)
#
# Options:
#   --output FILE   Output filename (default: INPUT_DIR/FULL_ALBUM_<cwd-name>.mp4)
#   -h, --help      Show this help message
#
# Details:
#   - Files are sorted alphabetically; FULL_ALBUM_* outputs are excluded.
#   - A 1-second black/silent gap is inserted between each track.
#   - Uses ffmpeg concat demuxer with -c copy (no re-encoding) — fast and lossless.
#   - All source files must share the same codec/resolution/framerate (guaranteed
#     when produced by render_single.sh with default settings).
#   - macOS AppleDouble (._*) files are ignored.

set -euo pipefail

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
}

# ── Argument parsing ───────────────────────────────────────────────────────────
INPUT_DIR="./rendered"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*)        echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)         INPUT_DIR="$1"; shift ;;
    esac
done

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "ERROR: Input directory not found: $INPUT_DIR" >&2
    exit 1
fi

INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"

# Build sorted list of .mp4s, excluding FULL_ALBUM_ outputs and ._* macOS stubs.
FILES=()
while IFS= read -r -d '' f; do
    FILES+=("$f")
done < <(find "$INPUT_DIR" -maxdepth 1 -name "*.mp4" \
    ! -name "FULL_ALBUM_*" ! -name "._*" -print0 | sort -z)

COUNT="${#FILES[@]}"
if [[ "$COUNT" -eq 0 ]]; then
    echo "No .mp4 files found in '$INPUT_DIR'." >&2
    exit 1
fi

# Default output: INPUT_DIR/FULL_ALBUM_<basename of cwd>.mp4
if [[ -z "$OUTPUT_FILE" ]]; then
    CWD_NAME="$(basename "$(pwd)")"
    OUTPUT_FILE="${INPUT_DIR}/FULL_ALBUM_${CWD_NAME}.mp4"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Concatenating $COUNT tracks → $(basename "$OUTPUT_FILE")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Generate 1-second gap clip (black video + silence) ────────────────────────
# Encoded with the same settings as render_single.sh to ensure stream compat.
GAP="/tmp/gap_concat_$$.mp4"
echo "▶ Generating 1-second gap clip..."
ffmpeg -y \
    -f lavfi -i "color=black:s=1920x1080:r=30" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
    -t 1 \
    -c:v libx264 -profile:v high -preset medium -crf 20 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -movflags +faststart \
    "$GAP" 2>/dev/null
echo "✓ Gap clip → $GAP"

# ── Build ffmpeg concat file list ─────────────────────────────────────────────
# Format: one "file '/abs/path/to/file.mp4'" per line.
# Single quotes within paths are escaped as '\'' (POSIX quoting).
CONCAT_LIST="/tmp/concat_$$.txt"
: > "$CONCAT_LIST"

escape_path() {
    printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

GAP_ESC="$(escape_path "$GAP")"

for i in "${!FILES[@]}"; do
    f="${FILES[$i]}"
    f_esc="$(escape_path "$f")"
    printf "file '%s'\n" "$f_esc" >> "$CONCAT_LIST"
    # Insert gap between tracks (not after the last one)
    if [[ $i -lt $((COUNT - 1)) ]]; then
        printf "file '%s'\n" "$GAP_ESC" >> "$CONCAT_LIST"
    fi
done

TOTAL_ENTRIES=$(wc -l < "$CONCAT_LIST" | tr -d ' ')
echo "✓ Concat list: $COUNT tracks + $((COUNT - 1)) gaps = $TOTAL_ENTRIES entries"

# ── Concatenate ───────────────────────────────────────────────────────────────
echo "▶ Concatenating (stream copy, no re-encode)..."
ffmpeg -y \
    -f concat -safe 0 -i "$CONCAT_LIST" \
    -c copy \
    -movflags +faststart \
    "$OUTPUT_FILE"

# ── Cleanup ────────────────────────────────────────────────────────────────────
rm -f "$GAP" "$CONCAT_LIST"

echo ""
echo "✅ Done! → $OUTPUT_FILE"
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT_FILE" | cut -d. -f1)
RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT_FILE")
echo "   Duration: ${DURATION}s   Resolution: ${RES}"
ls -lh "$OUTPUT_FILE"
