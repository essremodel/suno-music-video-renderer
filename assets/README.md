# README visuals

- `hero.png`: original generated banner, coordinated with Suno Library Downloader's charcoal/orange presentation. This is branding artwork, not a software screenshot.
- `demo-cover.png`: original generated sunset artwork used as the embedded cover for the demonstration.
- `output-preview.jpg`: an actual frame extracted from a video rendered by the unchanged `render_single.sh`, using that cover and a two-second synthetic 440 Hz tone. It contains no downloaded song or account data.

## Reproduce the demonstration

From the repository root, activate the Python environment described in the README and set `TITLE_FONT` and `ARTIST_FONT` to real font files. Then:

```bash
mkdir -p /tmp/suno-render-demo
ffmpeg -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=2' \
  -i assets/demo-cover.png -map 0:a -map 1:v \
  -c:a libmp3lame -ac 2 -c:v mjpeg -id3v2_version 3 \
  -metadata:s:v title='Album cover' -metadata:s:v comment='Cover (front)' \
  -disposition:v attached_pic \
  '/tmp/suno-render-demo/Golden Hour – Renderer Demo [abc12345].mp3'
./render_single.sh --output-dir /tmp/suno-render-demo \
  '/tmp/suno-render-demo/Golden Hour – Renderer Demo [abc12345].mp3'
ffmpeg -i '/tmp/suno-render-demo/Golden Hour – Renderer Demo [abc12345].mp4' \
  -frames:v 1 -q:v 2 /tmp/suno-render-demo/output-preview.jpg
```

The source artwork is retained so the example can be regenerated. Generated MP3 and MP4 files are not committed. The banners and sample cover are intentionally high-resolution PNGs; the embedded output preview is a smaller JPEG.
