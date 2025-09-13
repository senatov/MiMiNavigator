#!/bin/zsh
# -*- coding: utf-8-with-bom -*-
set -euo pipefail

# ✅ Включение режима отладки
DEBUG=false
if [[ "${1:-}" == "-X" ]]; then
  DEBUG=true
fi

# ✅ Получение текущей даты и времени
NOW=$(date +"%Y.%m.%d %H:%M:%S")

# ✅ Получение имени хоста
HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname)

# ✅ Финальный формат версии
VERSION="$NOW at Host: $HOSTNAME"

# ✅ Определение пути к целевому файлу
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/Develop/MiMiNavigator/Gui"
TARGET_FILE="${TARGET_DIR}/curr_version.asc"

# ✅ Диагностика
echo "👣 Script started"
echo "📂 Script directory: $SCRIPT_DIR"
echo "📄 Target file: $TARGET_FILE"
echo "🕒 Generated VERSION: $VERSION"

# ✅ Создание директории при необходимости
mkdir -p "$TARGET_DIR"

# ✅ Проверка возможности записи
if ! touch "$TARGET_FILE" 2>/dev/null; then
  echo "❌ ERROR: Cannot write to $TARGET_FILE. Check permissions." >&2
  exit 1
fi

# ✅ Запись строки версии в файл
echo "$VERSION" > "$TARGET_FILE"

# ✅ Проверка, что файл не пуст
if [[ ! -s "$TARGET_FILE" ]]; then
  echo "❌ ERROR: $TARGET_FILE is empty after write!" >&2
  exit 2
fi

# ✅ Финальное сообщение
if $DEBUG; then
  echo "📦 Wrote version to $TARGET_FILE:"
  echo "$VERSION"
else
  echo "✅ Updated version"
fi