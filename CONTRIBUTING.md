# Contributing

Keep changes focused on a specific rendering or documentation improvement. Preserve the single-track, batch, concatenation, font, and filename documentation when reorganizing the README.

## Local checks

Follow the [installation instructions](./README.md#install), activate the Python environment, and set the font variables to existing files.

```bash
for file in render_single.sh render_all.sh render_concat.sh; do
  bash -n "$file" || exit 1
done
python -c "import ast, pathlib; ast.parse(pathlib.Path('add_text.py').read_text())"
git diff --check
```

There is no automated test suite or CI workflow in this repository. Syntax checks do not validate FFmpeg behavior.

For rendering changes, use short synthetic audio with embedded artwork. Check one render, batch output, skipping existing files, and concatenation with two compatible tracks. Inspect codecs, dimensions, frame rate, audio properties, and duration with `ffprobe`; watch the output and check title placement. Include a filename containing spaces and the documented artist separator.

## Documentation and assets

Keep all CLI flags and examples accurate against the scripts. Verify relative links and heading anchors, and inspect the README at desktop and narrow widths in both GitHub themes. Label demonstration media accurately. See [asset provenance](./assets/README.md).

Do not commit personal music libraries, generated MP4 batches, local font files, or environment folders. Pull requests should describe the improvement, checks performed, and any existing limitations observed.
