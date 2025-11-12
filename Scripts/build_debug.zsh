#!/bin/zsh
# Simple debug build script for MiMiNavigator with log to file.
# All comments in English as requested.

set -o pipefail

# Resolve project root (directory above scripts/)
SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LOG_DIR="${PROJECT_ROOT}/build-logs"
mkdir -p "${LOG_DIR}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="${LOG_DIR}/build-debug-${TIMESTAMP}.log"

echo "Project root: ${PROJECT_ROOT}"
echo "Log file    : ${LOG_FILE}"
echo "Starting xcodebuild (Debug)..."
echo

cd "${PROJECT_ROOT}" || exit 1

# Adjust these names to match your project/workspace/scheme
WORKSPACE="MiMiNavigator.xcworkspace"
PROJECT_FILE="MiMiNavigator.xcodeproj"
SCHEME="MiMiNavigator"
CONFIGURATION="Debug"

# Select workspace or project depending on what actually exists
BUILD_CMD=()

if [[ -d "${WORKSPACE}" ]]; then
  echo "Using workspace: ${WORKSPACE}"
  BUILD_CMD=(xcodebuild
    -workspace "${WORKSPACE}"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
    -destination 'platform=macOS'
    build)
elif [[ -d "${PROJECT_FILE}" ]]; then
  echo "Using project: ${PROJECT_FILE}"
  BUILD_CMD=(xcodebuild
    -project "${PROJECT_FILE}"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
    -destination 'platform=macOS'
    build)
else
  echo "error: Neither '${WORKSPACE}' nor '${PROJECT_FILE}' exists in ${PROJECT_ROOT}"
  exit 1
fi

# Run build and tee output to log file
"${BUILD_CMD[@]}" | tee "${LOG_FILE}"

EXIT_CODE=${pipestatus[1]}

echo
echo "xcodebuild finished with exit code: ${EXIT_CODE}"
echo "Log saved to: ${LOG_FILE}"

exit ${EXIT_CODE}