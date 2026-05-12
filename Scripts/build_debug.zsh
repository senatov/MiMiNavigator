#!/bin/zsh
# MARK: - build_debug.zsh
# Fast Debug build for local development.
# Usage: zsh Scripts/build_debug.zsh

set -eo pipefail

PROJECT_DIR="/Users/senat/Develop/MiMiNavigator"
PROJECT_FILE="${PROJECT_DIR}/MiMiNavigator.xcodeproj"
SCHEME="MiMiNavigator"
CONFIG="Debug"
BUILD_LOG="/tmp/mimi_build.log"

echo "=== MiMiNavigator debug build ==="
cd "${PROJECT_DIR}"

echo "[1/3] Updating version file..."
zsh "${PROJECT_DIR}/Scripts/stamp_version.zsh"

echo "[2/3] Building ${SCHEME} (${CONFIG})..."
xcodebuild build \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -destination "platform=macOS" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "${BUILD_LOG}" | grep -E "(error:|warning:|BUILD)" | tail -60

BUILD_EXIT=${pipestatus[1]}

if [[ ${BUILD_EXIT} -ne 0 ]]; then
    echo ""
    echo "=== BUILD FAILED ==="
    echo "Log: ${BUILD_LOG}"
    echo "Errors:"
    grep "error:" "${BUILD_LOG}" | tail -10
    exit ${BUILD_EXIT}
fi

APP_PATH=$(find "${HOME}/Library/Developer/Xcode/DerivedData"/MiMiNavigator-*/Build/Products/"${CONFIG}" -maxdepth 1 -name "MiMiNavigator.app" 2>/dev/null | head -1)

echo "[3/3] Done."
echo ""
echo "=== BUILD SUCCEEDED (${CONFIG}) ==="
if [[ -n "${APP_PATH}" ]]; then
    echo "App:  ${APP_PATH}"
    echo "Size: $(du -sh "${APP_PATH}" | cut -f1)"
fi
echo "Log:  ${BUILD_LOG}"
