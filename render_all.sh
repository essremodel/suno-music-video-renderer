#!/usr/bin/env bash
# render_all.sh — Batch render every MP3 in a directory into music videos.
#
# Usage:
#   render_all.sh [OPTIONS]
#
# Options:
#   --input-dir  DIR   Directory containing .mp3 files (default: .)
#   --output-dir DIR   Directory to write .mp4 files   (default: ./rendered)
#   --concat           After rendering, run render_concat.sh on the output dir
#   -h, --help         Show this help message
#
# Already-rendered files are skipped automatically (delete the .mp4 to re-render).
# macOS AppleDouble (._*) stub files are ignored.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENDER_SINGLE="$SCRIPT_DIR/render_single.sh"
RENDER_CONCAT="$SCRIPT_DIR/render_concat.sh"

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
}

# ── Argument parsing ───────────────────────────────────────────────────────────
INPUT_DIR="."
OUTPUT_DIR="./rendered"
DO_CONCAT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input-dir)  INPUT_DIR="$2";  shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --concat)     DO_CONCAT=1;     shift ;;
        -h|--help)    usage; exit 0 ;;
        *)            echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

# Resolve to absolute paths so render_single.sh works from any CWD.
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# ── Validate ───────────────────────────────────────────────────────────────────
if [[ ! -x "$RENDER_SINGLE" ]]; then
    echo "ERROR: render_single.sh not found or not executable at $RENDER_SINGLE" >&2
    exit 1
fi

TOTAL=$(find "$INPUT_DIR" -maxdepth 1 -name "*.mp3" ! -name "._*" | wc -l | tr -d ' ')
if [[ "$TOTAL" -eq 0 ]]; then
    echo "No .mp3 files found in '$INPUT_DIR'." >&2
    exit 1
fi

# ── Header ─────────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════╗"
echo "║  Suno Music Video Renderer               ║"
printf "║  Found:  %-33s║\n" "$TOTAL MP3s"
printf "║  Input:  %-33s║\n" "$INPUT_DIR"
printf "║  Output: %-33s║\n" "$OUTPUT_DIR"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Render loop ────────────────────────────────────────────────────────────────
COUNT=0
FAILED=0
SKIPPED=0

while IFS= read -r -d '' mp3; do
    BASENAME="$(basename "$mp3" .mp3)"
    OUTFILE="${OUTPUT_DIR}/${BASENAME}.mp4"
    COUNT=$((COUNT + 1))

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  [%d/%d] %s\n" "$COUNT" "$TOTAL" "$BASENAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -f "$OUTFILE" ]]; then
        echo "  ⏭  Already rendered, skipping."
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if "$RENDER_SINGLE" --output-dir "$OUTPUT_DIR" "$mp3"; then
        echo "  ✅ → $OUTFILE"
    else
        echo "  ❌ FAILED: $(basename "$mp3")"
        FAILED=$((FAILED + 1))
    fi
done < <(find "$INPUT_DIR" -maxdepth 1 -name "*.mp3" ! -name "._*" -print0 | sort -z)

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  COMPLETE                                ║"
printf "║  Rendered: %-31s║\n" "$((COUNT - FAILED - SKIPPED))/$TOTAL"
printf "║  Skipped:  %-31s║\n" "$SKIPPED"
printf "║  Failed:   %-31s║\n" "$FAILED"
echo "╚══════════════════════════════════════════╝"

# ── Optional concat ────────────────────────────────────────────────────────────
if [[ "$DO_CONCAT" -eq 1 ]]; then
    if [[ ! -x "$RENDER_CONCAT" ]]; then
        echo "WARNING: --concat specified but render_concat.sh not found at $RENDER_CONCAT" >&2
    else
        echo ""
        echo "▶ Running render_concat.sh on $OUTPUT_DIR ..."
        "$RENDER_CONCAT" "$OUTPUT_DIR"
    fi
fi

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
