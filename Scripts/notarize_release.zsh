#!/bin/zsh
# MARK: - notarize_release.zsh
# Full pipeline: version stamp → clean Release build with Developer ID signing
# → hardened runtime → DMG → notarize → staple → upload to GitHub release.
#
# Usage:  zsh Scripts/notarize_release.zsh <version>
# Example: zsh Scripts/notarize_release.zsh 0.9.7.1
#
# Prerequisites:
#   brew install gh && gh auth login
#   Developer ID Application certificate in Keychain
#   App-specific password in ~/.ssh/mimi_notary_password

set -eo pipefail

# ── Credentials ───────────────────────────────────────────────────────────────
APPLE_ID="senatov@icloud.com"
TEAM_ID="G2V9T9AD95"
SIGN_IDENTITY="Developer ID Application: Iakov Senatov (${TEAM_ID})"
KEYCHAIN_PROFILE="MiMiNotary"

# read app-specific password from secure file
PASS_FILE="${HOME}/.ssh/mimi_notary_password"
if [[ ! -f "${PASS_FILE}" ]]; then
    echo "❌ App-specific password not found: ${PASS_FILE}"
    echo "   Create it:  echo 'xxxx-xxxx-xxxx-xxxx' > ~/.ssh/mimi_notary_password && chmod 600 ~/.ssh/mimi_notary_password"
    exit 1
fi
APP_PASSWORD="$(head -1 "${PASS_FILE}" | tr -d '[:space:]')"

# ── Args ──────────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    print -u2 "Usage: $0 <version>   e.g. $0 0.9.7.1"
    exit 1
fi

VERSION="$1"
TAG="v${VERSION}"

# ── Paths ─────────────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="${PROJECT_DIR}/MiMiNavigator.xcodeproj"
SCHEME="MiMiNavigator"
CONFIG="Release"
BUILD_DIR="/tmp/mimi_notarize_build"
BUILD_LOG="/tmp/mimi_notarize_build.log"
DMG="/tmp/MiMiNavigator-${VERSION}.dmg"
DMG_STAGE="/tmp/mimi_dmg_notarize"
DERIVED_DATA_ROOT="${HOME}/Library/Developer/Xcode/DerivedData"

echo "═══════════════════════════════════════════"
echo "  MiMiNavigator Notarized Release ${TAG}"
echo "═══════════════════════════════════════════"
cd "${PROJECT_DIR}"

# ── Pre-flight checks ────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
    echo "❌ gh not found. Install: brew install gh && gh auth login"
    exit 1
fi
if ! gh auth status &>/dev/null; then
    echo "❌ gh not authenticated. Run: gh auth login"
    exit 1
fi

# ── Step 1: Version stamp ─────────────────────────────────────────────────────
echo "[1/10] Updating version stamp..."
Scripts/refreshVersionFile.zsh

# ── Step 2: Kill Xcode ────────────────────────────────────────────────────────
echo "[2/10] Killing Xcode..."
killall Xcode 2>/dev/null && sleep 2 || echo "   Xcode not running"

# ── Step 2.5: Unlock keychain for codesign ────────────────────────────────────
if security show-keychain-info ~/Library/Keychains/login.keychain-db 2>/dev/null; then
    echo "[2.5/10] Keychain already unlocked — skipping"
else
    echo "[2.5/10] Unlocking login keychain (enter your Mac login password)..."
    security unlock-keychain ~/Library/Keychains/login.keychain-db
fi

# ── Step 3: Nuke DerivedData ──────────────────────────────────────────────────
echo "[3/10] Removing DerivedData..."
for dd in "${DERIVED_DATA_ROOT}"/MiMiNavigator-*; do
    [[ -d "$dd" ]] && rm -rf "$dd" && echo "   Removed: $(basename $dd)"
done
rm -rf "${BUILD_DIR}" && echo "   Removed: ${BUILD_DIR}"

# ── Step 4: Nuke SPM caches ──────────────────────────────────────────────────
echo "[4/10] Clearing SPM caches..."
rm -rf "${HOME}/Library/Caches/org.swift.swiftpm" 2>/dev/null
rm -rf "${HOME}/Library/org.swift.swiftpm" 2>/dev/null
rm -rf "${PROJECT_DIR}/.build" 2>/dev/null

# ── Step 5: Resolve packages ─────────────────────────────────────────────────
echo "[5/10] Resolving packages..."
xcodebuild -resolvePackageDependencies \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -clonedSourcePackagesDirPath "${PROJECT_DIR}/.spm-checkouts" \
    2>&1 | tail -5

if [[ ${pipestatus[1]} -ne 0 ]]; then
    echo "❌ Package resolution failed."
    exit 1
fi

# ── Step 6: Clean Release build with Developer ID + hardened runtime ─────────
echo "[6/10] Building ${SCHEME} (${CONFIG}) with Developer ID signing..."
xcodebuild clean build \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -derivedDataPath "${BUILD_DIR}" \
    -clonedSourcePackagesDirPath "${PROJECT_DIR}/.spm-checkouts" \
    CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
    CODE_SIGNING_ALLOWED=YES \
    2>&1 | tee "${BUILD_LOG}" | grep -E "(error:|warning:|BUILD|CLEAN|Signing)" | tail -30

BUILD_EXIT=${pipestatus[1]}
if [[ ${BUILD_EXIT} -ne 0 ]]; then
    echo ""
    echo "=== ❌ BUILD FAILED ==="
    echo "Log: ${BUILD_LOG}"
    grep "error:" "${BUILD_LOG}" | tail -10
    exit 1
fi

# ── Step 7: Verify signature + strip quarantine ──────────────────────────────
APP="${BUILD_DIR}/Build/Products/${CONFIG}/MiMiNavigator.app"
if [[ ! -d "${APP}" ]]; then
    echo "❌ .app not found at ${APP}"
    exit 1
fi
echo "[7/10] Verifying code signature..."
codesign --verify --deep --strict "${APP}" 2>&1 && echo "   ✅ Signature valid" || {
    echo "❌ Signature verification failed!"
    exit 1
}
xattr -cr "${APP}"

# ── Step 8: Create DMG ───────────────────────────────────────────────────────
echo "[8/10] Creating DMG..."
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP}" "${DMG_STAGE}/"
xattr -cr "${DMG_STAGE}/MiMiNavigator.app"

rm -f "${DMG}"
hdiutil create \
    -volname "MiMiNavigator" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    "${DMG}"
echo "   DMG: ${DMG} ($(du -sh "${DMG}" | cut -f1))"

# ── Step 9: Notarize ─────────────────────────────────────────────────────────
echo "[9/10] Ensuring keychain credentials..."
xcrun notarytool store-credentials "${KEYCHAIN_PROFILE}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${APP_PASSWORD}" 2>&1 | tail -3

echo "   Submitting to Apple notary service (this may take 5-15 min)..."
xcrun notarytool submit "${DMG}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait 2>&1 | tee /tmp/mimi_notarize_result.log

NOTARY_EXIT=$?
if [[ ${NOTARY_EXIT} -ne 0 ]]; then
    echo "❌ Notarization failed! Check /tmp/mimi_notarize_result.log"
    echo "   Run: xcrun notarytool log <submission-id> --keychain-profile ${KEYCHAIN_PROFILE}"
    exit 1
fi

if ! grep -q "status: Accepted" /tmp/mimi_notarize_result.log; then
    echo "⚠️  Notarization did not return 'Accepted'. Check the log."
    cat /tmp/mimi_notarize_result.log
    exit 1
fi

echo "   ✅ Notarization accepted!"
echo "   Stapling ticket to DMG..."
xcrun stapler staple "${DMG}"

# ── Step 10: Upload to GitHub ─────────────────────────────────────────────────
echo "[10/10] Uploading to GitHub release ${TAG}..."

if gh release view "${TAG}" &>/dev/null; then
    echo "   Release ${TAG} exists, uploading DMG..."
    gh release upload "${TAG}" "${DMG}" --clobber
else
    echo "   Creating release ${TAG}..."
    gh release create "${TAG}" "${DMG}" \
        --title "${TAG} — MiMiNavigator (notarized)" \
        --notes "Notarized release. Mount DMG, drag to Applications, done."
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ NOTARIZED RELEASE COMPLETE"
echo "═══════════════════════════════════════════"
echo "  Version: ${VERSION}"
echo "  App:     ${APP} ($(du -sh "${APP}" | cut -f1))"
echo "  DMG:     ${DMG} ($(du -sh "${DMG}" | cut -f1))"
echo "  GitHub:  https://github.com/senatov/MiMiNavigator/releases/tag/${TAG}"
echo ""
echo "  Notarized — no xattr -cr needed! 🎉"
echo "═══════════════════════════════════════════"
