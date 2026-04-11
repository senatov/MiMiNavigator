#!/bin/zsh

# TGS to GIF converter with timestamp and trash cleanup
# Uses lottie-converter for fast rendering

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: tgs2gif.zsh input.tgs"
  exit 1
fi

input="$1"

# Validate input
if [[ "${input:e}" != "tgs" ]]; then
  echo "❌ Input must be a .tgs file"
  exit 2
fi

if [[ ! -f "$input" ]]; then
  echo "❌ File not found: $input"
  exit 3
fi

# Generate output filename with timestamp
timestamp=$(date "+%Y%m%d-%H%M%S")
basename="${input:t:r}"
output="${input:h}/${basename}_${timestamp}.gif"

echo "🎬 Converting TGS to GIF..."

# Convert using lottie_to_gif.sh
lottie_to_gif.sh "$input" --output "$output" || { echo "❌ Conversion failed"; exit 4; }

# Move original to Trash
echo "🗑 Moving original to Trash..."
mv "$input" ~/.Trash/

echo "✅ Done: $output"
ls -lh "$output"