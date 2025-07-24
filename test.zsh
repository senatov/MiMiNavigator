#!/bin/zsh

echo "👣 Script started"

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
echo "📂 Script directory: ${SCRIPT_DIR}"

TARGET_FILE="${SCRIPT_DIR}/../MMNavigator/MiMiNavigator/Config/curr_version.asc"
echo "📄 Target file: ${TARGET_FILE}"

VERSION_STRING="$(date +"%Y.%m.%d %H:%M:%S") at Host: $(scutil --get ComputerName)"
echo "🕒 Generated VERSION: ${VERSION_STRING}"

# Just try to write directly — do NOT mkdir anything
echo "${VERSION_STRING}" > "${TARGET_FILE}" || {
  echo "❌ Failed to write version file"
  exit 1
}

echo "✅ Version written to ${TARGET_FILE}"
