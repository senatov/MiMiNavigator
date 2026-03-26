#!/bin/zsh
# MARK: - local_release.zsh
# Full clean Release build → .dmg for MiMiNavigator.
# Nukes SPM cache + DerivedData, resolves packages, builds Release, creates DMG.
# Usage: zsh Scripts/local_release.zsh

set -eo pipefail

PROJECT_DIR="/Users/senat/Develop/MiMiNavigator"
PROJECT_FILE="${PROJECT_DIR}/MiMiNavigator.xcodeproj"
SCHEME="MiMiNavigator"
CONFIG="Release"
BUILD_DIR="/tmp/mimi_build"
BUILD_LOG="/tmp/mimi_release_build.log"
DMG="/tmp/MiMiNavigator.dmg"
DMG_STAGE="/tmp/mimi_dmg"
DERIVED_DATA_ROOT="${HOME}/Library/Developer/Xcode/DerivedData"

echo "=== MiMiNavigator local release ==="
cd "${PROJECT_DIR}"

# 1. Version stamp
echo "[1/9] Updating version file..."
Scripts/refreshVersionFile.zsh

# 2. Kill Xcode to release file locks
echo "[2/9] Killing Xcode..."
killall Xcode 2>/dev/null && sleep 2 || echo "  Xcode not running"

# 3. Nuke DerivedData for this project
echo "[3/9] Removing DerivedData..."
for dd in "${DERIVED_DATA_ROOT}"/MiMiNavigator-*; do
    [[ -d "$dd" ]] && rm -rf "$dd" && echo "  Removed: $(basename $dd)"
done
rm -rf "${BUILD_DIR}" && echo "  Removed: ${BUILD_DIR}"

# 4. Nuke SPM caches (global + local)
echo "[4/9] Clearing SPM caches..."
rm -rf "${HOME}/Library/Caches/org.swift.swiftpm" 2>/dev/null && echo "  Removed org.swift.swiftpm cache"
rm -rf "${HOME}/Library/org.swift.swiftpm" 2>/dev/null && echo "  Removed org.swift.swiftpm state"
rm -rf "${PROJECT_DIR}/.build" 2>/dev/null && echo "  Removed .build"

# 5. Resolve packages fresh
echo "[5/9] Resolving packages..."
xcodebuild -resolvePackageDependencies \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -clonedSourcePackagesDirPath "${PROJECT_DIR}/.spm-checkouts" \
    2>&1 | tail -5

if [[ ${pipestatus[1]} -ne 0 ]]; then
    echo "ERROR: Package resolution failed. Check network/versions."
    exit 1
fi

# 6. Clean + Release build
echo "[6/9] Building ${SCHEME} (${CONFIG})..."
xcodebuild clean build \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "${BUILD_LOG}" | grep -E "(error:|warning:|BUILD|CLEAN)" | tail -30

BUILD_EXIT=${pipestatus[1]}

if [[ ${BUILD_EXIT} -ne 0 ]]; then
    echo ""
    echo "=== BUILD FAILED ==="
    echo "Log: ${BUILD_LOG}"
    echo "Errors:"
    grep "error:" "${BUILD_LOG}" | tail -10
    exit 1
fi

# 7. Strip quarantine & extended attributes
APP="${BUILD_DIR}/Build/Products/${CONFIG}/MiMiNavigator.app"
if [[ ! -d "${APP}" ]]; then
    echo "ERROR: .app not found at ${APP}"
    exit 1
fi
echo "[7/9] Clearing extended attributes (xattr -cr)..."
xattr -cr "${APP}"

# 8. Create DMG
echo "[8/9] Creating DMG..."
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP}" "${DMG_STAGE}/"
xattr -cr "${DMG_STAGE}/MiMiNavigator.app"
echo "   xattr cleared on staged app"

rm -f "${DMG}"
hdiutil create \
    -volname "MiMiNavigator" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    "${DMG}"

# 9. Summary
echo "[9/9] Done."
echo ""
echo "=== RELEASE BUILD SUCCEEDED ==="
echo "App:  ${APP}"
echo "Size: $(du -sh "${APP}" | cut -f1)"
echo "DMG:  ${DMG}"
echo "DMG size: $(du -sh "${DMG}" | cut -f1)"
echo "Log:  ${BUILD_LOG}"
