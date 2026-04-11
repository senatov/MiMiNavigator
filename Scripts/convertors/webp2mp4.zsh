#!/bin/zsh

# WebP to MP4 converter with timestamp naming and auto-cleanup
# Converts animated WebP to video format

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: webp2mp4.zsh input.webp"
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

# Generate output filename: basename_YYYY-MM-DD_HH-MM-SS.mp4
timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
basename="${input:t:r}"
output="${input:h}/${basename}_${timestamp}.mp4"

echo "🎬 Converting WebP to MP4..."

# Convert WebP to MP4 using ffmpeg
ffmpeg -hide_banner -loglevel error -i "$input" \
  -c:v libx264 -pix_fmt yuv420p -preset fast -crf 23 \
  -movflags +faststart \
  "$output" || {
    echo "❌ Conversion failed"
    exit 5
  }

# Move original to Trash
echo "🗑 Moving original to Trash..."
mv "$input" ~/.Trash/

echo "✅ Done: $output"
ls -lh "$output"