#!/bin/zsh

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <file.webm|file.webp>"
  exit 1
fi

INPUT="$1"

if [[ ! -f "$INPUT" ]]; then
  echo "❌ File not found: $INPUT"
  exit 1
fi

ext="${INPUT##*.}"
BASENAME=$(basename "$INPUT" .$ext)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="${HOME}/Downloads/Musor/${BASENAME}_${TIMESTAMP}.gif"

if [[ "$ext" != "webm" && "$ext" != "webp" ]]; then
  echo "❌ Unsupported input format: .$ext"
  exit 1
fi

echo "🎨 Converting $INPUT → $OUTFILE..."

# Настройки GIF
FPS=12
SCALE=512

# Временная директория
TMPDIR=$(mktemp -d)
TMPGIF="$TMPDIR/tmp.gif"

# Конвертация
ffmpeg -hide_banner -loglevel error -y \
  -i "$INPUT" -vf "fps=$FPS,scale=$SCALE:-1:flags=lanczos" \
  "$TMPGIF"

# Оптимизация
gifsicle -O3 "$TMPGIF" > "$OUTFILE"

# Удаление оригинального файла
echo "🗑 Moving original file to Trash..."
osascript -e "tell application \"Finder\" to delete POSIX file \"$(realpath "$INPUT")\""

echo "✅ Done: $OUTFILE"
rm -rf "$TMPDIR"

# Путь к текущему скрипту
SCRIPT_NAME="$(basename "$0")"

# Удалим все строки, содержащие имя скрипта, из zsh_history
sed -i '' "/$SCRIPT_NAME/d" ~/.zsh_history

# Сбросим текущую историю
fc -p

# Перечитаем историю (чтобы очистить её из памяти)
fc -R