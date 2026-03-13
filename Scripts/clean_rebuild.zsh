#!/bin/zsh
# MARK: - clean_rebuild.zsh
# Full clean rebuild for MiMiNavigator — nukes SPM cache + DerivedData, resolves packages, builds.
# Usage: zsh Scripts/clean_rebuild.zsh [--release]

set -eo pipefail

PROJECT_DIR="/Users/senat/Develop/MiMiNavigator"
PROJECT_FILE="${PROJECT_DIR}/MiMiNavigator.xcodeproj"
SCHEME="MiMiNavigator"
DERIVED_DATA_ROOT="${HOME}/Library/Developer/Xcode/DerivedData"

if [[ "${1:-}" == "--release" ]]; then
    CONFIG="Release"
else
    CONFIG="Debug"
fi

echo "=== MiMiNavigator clean rebuild (${CONFIG}) ==="
cd "${PROJECT_DIR}"

# 1. Kill Xcode to release file locks
echo "[1/7] Killing Xcode..."
killall Xcode 2>/dev/null && sleep 2 || echo "  Xcode not running"

# 2. Nuke DerivedData for this project
echo "[2/7] Removing DerivedData..."
for dd in "${DERIVED_DATA_ROOT}"/MiMiNavigator-*; do
    [[ -d "$dd" ]] && rm -rf "$dd" && echo "  Removed: $(basename $dd)"
done

# 3. Nuke SPM caches (global + local)
echo "[3/7] Clearing SPM caches..."
rm -rf "${HOME}/Library/Caches/org.swift.swiftpm" 2>/dev/null && echo "  Removed org.swift.swiftpm cache"
rm -rf "${HOME}/Library/org.swift.swiftpm" 2>/dev/null && echo "  Removed org.swift.swiftpm state"
rm -rf "${PROJECT_DIR}/.build" 2>/dev/null && echo "  Removed .build"

# 4. Resolve packages fresh
echo "[4/7] Resolving packages..."
xcodebuild -resolvePackageDependencies \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -clonedSourcePackagesDirPath "${PROJECT_DIR}/.spm-checkouts" \
    2>&1 | tail -5

if [[ ${pipestatus[1]} -ne 0 ]]; then
    echo "ERROR: Package resolution failed. Check network/versions."
    exit 1
fi

# 5. Clean + build (single xcodebuild invocation)
echo "[5/7] Building ${SCHEME} (${CONFIG})..."
xcodebuild clean build \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee /tmp/mimi_build.log | grep -E "(error:|warning:|BUILD|CLEAN)" | tail -30

BUILD_EXIT=${pipestatus[1]}

# 6. Strip quarantine & extended attributes from .app
echo ""
if [[ ${BUILD_EXIT} -eq 0 ]]; then
    APP_PATH=$(find "${DERIVED_DATA_ROOT}"/MiMiNavigator-*/Build/Products/"${CONFIG}" -name "MiMiNavigator.app" -maxdepth 1 2>/dev/null | head -1)
    if [[ -n "${APP_PATH}" ]]; then
        echo "[6/7] Clearing extended attributes (xattr -cr)..."
        xattr -cr "${APP_PATH}"

        # 7. Summary
        echo "[7/7] Done."
        echo ""
        echo "=== BUILD SUCCEEDED (${CONFIG}) ==="
        echo "App:  ${APP_PATH}"
        echo "Size: $(du -sh "${APP_PATH}" | cut -f1)"
        echo "Log:  /tmp/mimi_build.log"
    else
        echo "=== BUILD SUCCEEDED (${CONFIG}) ==="
        echo "Warning: .app bundle not found in DerivedData"
        echo "Log: /tmp/mimi_build.log"
    fi
else
    echo "=== BUILD FAILED ==="
    echo "Log: /tmp/mimi_build.log"
    echo "Errors:"
    grep "error:" /tmp/mimi_build.log | tail -10
    exit 1
fi
