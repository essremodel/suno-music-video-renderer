#!/usr/bin/env python3
"""
add_text.py — Overlay song title and artist name onto a 1920x1080 video frame.

Usage:
    python3 add_text.py <frame_in> <frame_out> <title> <artist> [OPTIONS]

Arguments:
    frame_in     Input frame image (PNG/JPG)
    frame_out    Output frame image path
    title        Song title text
    artist       Artist name text

Options:
    --title-size N    Title font size in pixels (default: 52)
    --artist-size N   Artist font size in pixels (default: 36)
    -h, --help        Show this help message

Environment variables:
    TITLE_FONT    Path to font file for title  (default: /Library/Fonts/Arial.ttf)
    ARTIST_FONT   Path to font file for artist (default: /Library/Fonts/Arial.ttf)

Layout:
    Title:  white, stroke_width=4, top of text ~160px from bottom
    Artist: white 85% opacity, stroke_width=2, top of text ~100px from bottom
    Both are horizontally centered.
"""

import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

DEFAULT_FONT = "/Library/Fonts/Arial.ttf"


def draw_centered(draw, text, font, y_top, fill, stroke_w, stroke_fill, img_w):
    """Draw text centered horizontally at the given y position."""
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    x = (img_w - text_w) // 2
    draw.text(
        (x, y_top),
        text,
        font=font,
        fill=fill,
        stroke_width=stroke_w,
        stroke_fill=stroke_fill,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Overlay title/artist text onto a video frame image.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("frame_in",      help="Input frame image path")
    parser.add_argument("frame_out",     help="Output frame image path")
    parser.add_argument("title",         help="Song title text")
    parser.add_argument("artist",        help="Artist name text")
    parser.add_argument(
        "--title-size", type=int, default=52,
        help="Title font size in px (default: 52)",
    )
    parser.add_argument(
        "--artist-size", type=int, default=36,
        help="Artist font size in px (default: 36)",
    )
    args = parser.parse_args()

    title_font_path  = os.environ.get("TITLE_FONT",  DEFAULT_FONT)
    artist_font_path = os.environ.get("ARTIST_FONT", DEFAULT_FONT)

    for path in (title_font_path, artist_font_path):
        if not os.path.isfile(path):
            print(f"ERROR: Font file not found: {path}", file=sys.stderr)
            print("Set TITLE_FONT / ARTIST_FONT env vars to override.", file=sys.stderr)
            sys.exit(1)

    img  = Image.open(args.frame_in).convert("RGB")
    draw = ImageDraw.Draw(img)
    W, H = img.size

    font_title  = ImageFont.truetype(title_font_path,  args.title_size)
    font_artist = ImageFont.truetype(artist_font_path, args.artist_size)

    # Title: white with black outline, top of text ~160px from bottom
    draw_centered(
        draw, args.title, font_title,
        y_top=H - 160,
        fill=(255, 255, 255, 255),
        stroke_w=4,
        stroke_fill=(0, 0, 0, 200),
        img_w=W,
    )

    # Artist: white 85% opacity with black outline, top of text ~100px from bottom
    draw_centered(
        draw, args.artist, font_artist,
        y_top=H - 100,
        fill=(255, 255, 255, 217),   # 217 ≈ 0.85 × 255
        stroke_w=2,
        stroke_fill=(0, 0, 0, 200),
        img_w=W,
    )

    img.save(args.frame_out)


if __name__ == "__main__":
    main()
