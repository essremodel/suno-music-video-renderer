# suno-music-video-renderer

Batch-render [Suno](https://suno.com) MP3 downloads into YouTube-style 1920×1080 music videos. Each video shows the embedded album art centered over a blurred/darkened version of itself as the background, with the song title and artist name in white text near the bottom of the frame.

## Output format

- **Resolution:** 1920×1080 (1080p)
- **Video:** H.264, 30fps, static frame (no waveform animation)
- **Audio:** AAC 192 kbps, copied from the source MP3
- **Container:** MP4 with faststart (moov atom at front, YouTube-friendly)

## Requirements

| Tool | Version | Notes |
|------|---------|-------|
| [ffmpeg](https://ffmpeg.org) | Any recent | Does **not** need `--enable-libfreetype` — text rendering uses Pillow instead |
| [ImageMagick 7](https://imagemagick.org) | 7.x (`magick` CLI) | Used for blur/composite; Freetype not required |
| Python 3 | 3.8+ | |
| [Pillow](https://pillow.readthedocs.io) | 9.2+ | `pip install Pillow` — handles all text rendering |

Install on macOS with Homebrew:

```bash
brew install ffmpeg imagemagick
pip3 install Pillow
```

### Font paths

By default `add_text.py` looks for `/Library/Fonts/Arial.ttf` (present on macOS with Office or as a standard system font). Override with environment variables:

```bash
export TITLE_FONT=/path/to/your/font-bold.ttf
export ARTIST_FONT=/path/to/your/font.ttf
```

## Filename format

Scripts expect the Suno download filename convention:

```
Song Title – Artist Name [hexhash].mp3
            ^
            em-dash (U+2013), not a regular hyphen
```

The `[hexhash]` suffix is stripped from the displayed title. If no ` – ` separator is found, the entire name (minus the hash) becomes the title.

## Quick start

### Render a single track

```bash
./render_single.sh "AYO (Boots Rockin') – Big Eazy [751f3115].mp3"
# Output: ./rendered/AYO (Boots Rockin') – Big Eazy [751f3115].mp4
```

Custom output directory:

```bash
./render_single.sh --output-dir ~/Desktop/videos "My Song – Artist [abc123].mp3"
```

### Render all MP3s in a directory

```bash
cd /path/to/your/mp3s
/path/to/render_all.sh
```

Or specify paths explicitly:

```bash
./render_all.sh --input-dir ~/Music/Suno --output-dir ~/Desktop/videos
```

Already-rendered files are skipped automatically. Delete the `.mp4` to force a re-render.

### Render all + concatenate into one full-album video

```bash
./render_all.sh --concat
# Renders all tracks, then produces: ./rendered/FULL_ALBUM_<dirname>.mp4
```

### Concatenate already-rendered files

```bash
./render_concat.sh ./rendered/
# Output: ./rendered/FULL_ALBUM_<cwd-name>.mp4
```

Custom output filename:

```bash
./render_concat.sh --output ~/Desktop/Big_Eazy_Full_Album.mp4 ./rendered/
```

## Command reference

### `render_single.sh`

```
render_single.sh [OPTIONS] "Song Title – Artist [hash].mp3"

Options:
  --output-dir DIR   Output directory (default: ./rendered)
  -h, --help         Show help
```

### `render_all.sh`

```
render_all.sh [OPTIONS]

Options:
  --input-dir  DIR   MP3 source directory (default: .)
  --output-dir DIR   Output directory     (default: ./rendered)
  --concat           Run render_concat.sh after all renders complete
  -h, --help         Show help
```

### `render_concat.sh`

```
render_concat.sh [OPTIONS] [INPUT_DIR]

Arguments:
  INPUT_DIR          Directory of .mp4 files (default: ./rendered)

Options:
  --output FILE      Output filename (default: INPUT_DIR/FULL_ALBUM_<cwd>.mp4)
  -h, --help         Show help
```

### `add_text.py`

```
add_text.py <frame_in> <frame_out> <title> <artist> [OPTIONS]

Options:
  --title-size N     Title font size px  (default: 52)
  --artist-size N    Artist font size px (default: 36)

Env vars:
  TITLE_FONT         Path to title font  (default: /Library/Fonts/Arial.ttf)
  ARTIST_FONT        Path to artist font (default: /Library/Fonts/Arial.ttf)
```

## How it works

Each `render_single.sh` call runs a four-step pipeline:

1. **`ffmpeg` — extract art**: Reads the MJPEG `attached_pic` stream embedded in the MP3 (Suno always includes 1024×1024 cover art) using `-map 0:v:0 -c:v copy`.

2. **`magick` — composite frame**: Scales the cover to fill 1920×1080 → applies a heavy gaussian blur (`-blur 0x30`) and slight darken (`-modulate 92`) for the background. Then overlays the original cover resized to 650px tall, centered and shifted 40px up.

3. **`add_text.py` — text overlay**: Opens the composite in Pillow and draws the song title (52px, white, stroke=4) and artist name (36px, white 85% opacity, stroke=2) centered near the bottom. Using Pillow instead of `ffmpeg drawtext` means no special-character escaping issues and no dependency on a Freetype-enabled ffmpeg build.

4. **`ffmpeg` — encode**: Loops the static frame at 30fps for the duration of the audio stream. Output is H.264/AAC in a faststart MP4.

## Known limitations

- **Static frame** — no waveform visualizer, spectrum, or animation. The video is a single still image for the full duration.
- **macOS font paths hardcoded** — `add_text.py` defaults to `/Library/Fonts/Arial.ttf`. Linux/Windows users must set `TITLE_FONT` / `ARTIST_FONT`.
- **Suno filename convention assumed** — the ` – ` em-dash separator and `[hexhash]` suffix are expected. Other formats will use the full filename as the title.
- **No chapter markers** — the full-album concat output is a single continuous stream with no chapter metadata.
- **Concat requires compatible streams** — `render_concat.sh` uses `-c copy` (no re-encode). All source files must share the same codec, resolution, and framerate. This is guaranteed when all files are produced by `render_single.sh` with default settings, but mixing externally-sourced files may cause issues.
