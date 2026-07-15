#!/bin/zsh
# MARK: - generate_dmg_background.zsh
# Generates the Finder DMG background image (660x400).
# with arrow and instruction text. Requires Python3 + Pillow.
#
# Usage: zsh Scripts/generate_dmg_background.zsh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT="${PROJECT_DIR}/Scripts/dmg_background.png"

python3 - "${OUTPUT}" << 'PYEOF'
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out_path = sys.argv[1]
W, H = 660, 400
img = Image.new('RGBA', (W, H))
draw = ImageDraw.Draw(img)

# Soft gradient — light gray-blue, Finder-style.
for y in range(H):
    t = y / H
    r = int(242 - 18 * t)
    g = int(242 - 18 * t)
    b = int(250 - 12 * t)
    draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

# Add a restrained light path between the two Finder icons.
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
glow_draw.ellipse((235, 120, 425, 270), fill=(92, 142, 238, 38))
glow = glow.filter(ImageFilter.GaussianBlur(36))
img = Image.alpha_composite(img, glow)

# Motion echoes suggest movement without pretending Finder supports animation.
echo_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
echo_draw = ImageDraw.Draw(echo_layer)
for offset, alpha in [(-75, 38), (-48, 66)]:
    x = 330 + offset
    echo_draw.line([(x - 16, 173), (x + 5, 190), (x - 16, 207)], fill=(82, 126, 220, alpha), width=5, joint='curve')
img = Image.alpha_composite(img, echo_layer)

# Main arrow with a single soft depth layer and a crisp highlight.
cx, cy = 330, 190
shaft = 68
head = 25
half_height = 19
arrow_points = [
    (cx - shaft, cy - 7),
    (cx + shaft - head, cy - 7),
    (cx + shaft - head, cy - half_height),
    (cx + shaft, cy),
    (cx + shaft - head, cy + half_height),
    (cx + shaft - head, cy + 7),
    (cx - shaft, cy + 7),
]
depth = Image.new('RGBA', (W, H), (0, 0, 0, 0))
depth_draw = ImageDraw.Draw(depth)
depth_draw.polygon([(x + 3, y + 4) for x, y in arrow_points], fill=(30, 55, 105, 80))
depth = depth.filter(ImageFilter.GaussianBlur(5))
img = Image.alpha_composite(img, depth)
arrow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
arrow_draw = ImageDraw.Draw(arrow)
arrow_draw.polygon(arrow_points, fill=(68, 113, 210, 255))
arrow_draw.line(arrow_points[:4], fill=(151, 187, 255, 230), width=2, joint='curve')
img = Image.alpha_composite(img, arrow)

# Bottom text.
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
except Exception:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSText.ttf", 15)
    except Exception:
        font = ImageFont.load_default()

text = "Drag MiMiNavigator to Applications to install"
draw = ImageDraw.Draw(img)
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, 24), text, fill=(72, 79, 103, 255), font=font)

img.convert('RGB').save(out_path, 'PNG', optimize=True)
print(f"✅ DMG background: {out_path}  ({W}x{H})")
PYEOF
