#!/bin/zsh

# WebP to GIF converter with timestamp naming and auto-cleanup
# Converts animated WebP to GIF format

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: webp2gif.zsh input.webp"
  exit 1
fi

input="$1"

# Validate input is a .webp file
if [[ "${input:e}" != "webp" ]]; then
  echo "❌ Input must be a .webp file"
  exit 2
fi

# Check if file exists
if [[ ! -f "$input" ]]; then
  echo "❌ File not found: $input"
  exit 3
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
  echo "❌ ffmpeg not found. Install with: brew install ffmpeg"
  exit 4
fi

# Generate output filename: basename_YYYY-MM-DD_HH-MM-SS.gif
timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
basename="${input:t:r}"
output="${input:h}/${basename}_${timestamp}.gif"

echo "🎬 Converting WebP to GIF..."

# Convert WebP to GIF using ffmpeg with optimization
ffmpeg -hide_banner -loglevel error -i "$input" \
  -vf "split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=bayer" \
  "$output" || {
    echo "❌ Conversion failed"
    exit 5
  }

# Move original to Trash
echo "🗑 Moving original to Trash..."
mv "$input" ~/.Trash/

echo "✅ Done: $output"
ls -lh "$output"