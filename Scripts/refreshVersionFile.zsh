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
VERSION_STRING="$NOW at Host: $HOSTNAME"

# ✅ Определение пути к целевому файлу
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$PROJECT_DIR/GUI/Resources"
TARGET_FILE="${TARGET_DIR}/curr_version.asc"
PBXPROJ="$PROJECT_DIR/MiMiNavigator.xcodeproj/project.pbxproj"

# ✅ Получение версии из git tag (e.g. "v0.9.7" → "0.9.7")
GIT=/usr/bin/git
if TAG=$($GIT -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null); then
    GIT_VERSION="${TAG#v}"
else
    GIT_VERSION="0.0.0"
fi

# ✅ Диагностика
echo "👣 Script started"
echo "📂 Script directory: $SCRIPT_DIR"
echo "📄 Target file: $TARGET_FILE"
echo "🕒 Generated VERSION: $VERSION_STRING"
echo "🏷️  Git tag version: $GIT_VERSION"

# ✅ Создание директории при необходимости
mkdir -p "$TARGET_DIR"

# ✅ Проверка возможности записи
if ! touch "$TARGET_FILE" 2>/dev/null; then
  echo "❌ ERROR: Cannot write to $TARGET_FILE. Check permissions." >&2
  exit 1
fi

# ✅ Запись строки версии в файл
echo "$VERSION_STRING" > "$TARGET_FILE"

# ✅ Проверка, что файл не пуст
if [[ ! -s "$TARGET_FILE" ]]; then
  echo "❌ ERROR: $TARGET_FILE is empty after write!" >&2
  exit 2
fi

# ✅ Обновление MARKETING_VERSION в pbxproj из git tag
if [[ -f "$PBXPROJ" ]]; then
  sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${GIT_VERSION}/" "$PBXPROJ"
  echo "📋 Updated MARKETING_VERSION → $GIT_VERSION"
fi

# ✅ Финальное сообщение
if $DEBUG; then
  echo "📦 Wrote version to $TARGET_FILE:"
  echo "$VERSION_STRING"
else
  echo "✅ Updated version: $GIT_VERSION ($VERSION_STRING)"
fi
