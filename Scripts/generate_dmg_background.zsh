#!/bin/zsh
# MARK: - generate_dmg_background.zsh
# Generates Retina DMG background image (660x400 @2x = 1320x800)
# with arrow and instruction text. Requires Python3 + Pillow.
#
# Usage: zsh Scripts/generate_dmg_background.zsh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT="${PROJECT_DIR}/Scripts/dmg_background.png"

python3 - "${OUTPUT}" << 'PYEOF'
import sys
from PIL import Image, ImageDraw, ImageFont

out_path = sys.argv[1]
W, H = 1320, 800
img = Image.new('RGB', (W, H))
draw = ImageDraw.Draw(img)

# soft gradient — light gray-blue, Finder-style
for y in range(H):
    t = y / H
    r = int(242 - 18 * t)
    g = int(242 - 18 * t)
    b = int(250 - 12 * t)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# center arrow between icon positions (app≈200, Applications≈460 in logical)
cx, cy = 660, 370
shaft = 90
head = 30
hw = 24
clr = (100, 100, 115)

draw.line([(cx - shaft, cy), (cx + shaft - head, cy)], fill=clr, width=7)
draw.polygon([
    (cx + shaft, cy),
    (cx + shaft - head, cy - hw),
    (cx + shaft - head, cy + hw),
], fill=clr)

# bottom text
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
except Exception:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSText.ttf", 24)
    except Exception:
        font = ImageFont.load_default()

text = "Drag MiMiNavigator to Applications to install"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, H - 70), text, fill=(140, 140, 160), font=font)

img.save(out_path, 'PNG')
print(f"✅ DMG background: {out_path}  ({W}x{H})")
PYEOF
