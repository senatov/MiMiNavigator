#!/bin/zsh
# MARK: - generate_dmg_background.zsh
# Renders the Finder DMG background from its vector source.
# Usage: zsh Scripts/generate_dmg_background.zsh

set -eo pipefail

SCRIPT_DIR="${0:A:h}"
SOURCE="${SCRIPT_DIR}/dmg_background.svg"
OUTPUT="${SCRIPT_DIR}/dmg_background.png"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "❌ rsvg-convert is required to generate the DMG background (brew install librsvg)" >&2
    exit 1
fi

rsvg-convert --width 660 --height 400 "${SOURCE}" --output "${OUTPUT}"
echo "✅ DMG background: ${OUTPUT} (660x400)"
