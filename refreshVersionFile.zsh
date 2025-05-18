#!/bin/zsh

# Определяем путь к корню проекта
PROJECT_ROOT="${SRCROOT:-$(pwd)}"

# Путь к .version-файлу в корне проекта
VERSION_FILE="$PROJECT_ROOT/MiMiNavigator/.version"

# Получение git-информации
GIT_COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null)
GIT_COMMIT_DATE=$(git log -1 --format=%cd --date=iso-strict 2>/dev/null)

# Формируем строку версии
if [[ -n "$GIT_COMMIT_HASH" && -n "$GIT_COMMIT_DATE" ]]; then
  echo "Mimi Navigator — $GIT_COMMIT_HASH — Senatov — $GIT_COMMIT_DATE" > "$VERSION_FILE"
else
  echo "Mimi Navigator — Unknown version — Senatov — $(date -Iseconds)" > "$VERSION_FILE"
fi