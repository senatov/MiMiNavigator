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
RELEASE_VERSION="${VERSION}" Scripts/refreshVersionFile.zsh

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
for dd in "${DERIVED_DATA_ROOT}"/MiMiNavigator-*(N); do
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
    2>&1 | tee "${BUILD_LOG}" | grep -E "(error:|warning:|BUILD|CLEAN|Signing|CompileSwift)" | tail -40

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

# ── Step 8: Create fancy DMG with background + Applications symlink ──────────
echo "[8/10] Creating fancy DMG installer..."
DMG_BG="${PROJECT_DIR}/Scripts/dmg_background.png"
DMG_RW="/tmp/MiMiNavigator-${VERSION}-rw.dmg"
DMG_VOL="MiMiNavigator"
DMG_WINDOW_LEFT=200
DMG_WINDOW_TOP=120
DMG_WINDOW_WIDTH=660
DMG_WINDOW_HEIGHT=400
DMG_WINDOW_RIGHT=$((DMG_WINDOW_LEFT + DMG_WINDOW_WIDTH))
DMG_WINDOW_BOTTOM=$((DMG_WINDOW_TOP + DMG_WINDOW_HEIGHT))
DMG_APP_X=170
DMG_APP_Y=190
DMG_APPS_X=490
DMG_APPS_Y=190
DMG_HIDDEN_X=120
DMG_HIDDEN_Y=540

# generate background if missing
if [[ ! -f "${DMG_BG}" ]]; then
    echo "   Generating DMG background..."
    zsh "${PROJECT_DIR}/Scripts/generate_dmg_background.zsh"
fi

# prepare staging folder
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP}" "${DMG_STAGE}/"
xattr -cr "${DMG_STAGE}/MiMiNavigator.app"
ln -s /Applications "${DMG_STAGE}/Applications"

# create read-write DMG first
rm -f "${DMG_RW}" "${DMG}"
hdiutil create \
    -volname "${DMG_VOL}" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDRW \
    "${DMG_RW}"

# mount r/w, style with AppleScript
MOUNT_OUT=$(hdiutil attach -readwrite -noverify "${DMG_RW}" | grep '/Volumes/')
DEVICE=$(echo "${MOUNT_OUT}" | head -1 | awk '{print $1}')
MOUNT_PT=$(echo "${MOUNT_OUT}" | head -1 | sed 's|.*\(/Volumes/.*\)|\1|')
sleep 2

# copy background into hidden .background dir
mkdir -p "${MOUNT_PT}/.background"
cp "${DMG_BG}" "${MOUNT_PT}/.background/background.png"

# style the Finder window via AppleScript
echo "   Styling DMG window..."
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "${DMG_VOL}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {${DMG_WINDOW_LEFT}, ${DMG_WINDOW_TOP}, ${DMG_WINDOW_RIGHT}, ${DMG_WINDOW_BOTTOM}}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        set position of item "MiMiNavigator.app" of container window to {${DMG_APP_X}, ${DMG_APP_Y}}
        set position of item "Applications" of container window to {${DMG_APPS_X}, ${DMG_APPS_Y}}
        set hiddenItemX to ${DMG_HIDDEN_X}
        repeat with hiddenItemName in {".background", ".DS_Store", ".fseventsd", ".Trashes", ".VolumeIcon.icns"}
            try
                set position of item (hiddenItemName as text) of container window to {hiddenItemX, ${DMG_HIDDEN_Y}}
            end try
            set hiddenItemX to hiddenItemX + 180
        end repeat
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

sync
sleep 2
hdiutil detach "${DEVICE}"
sleep 1

# convert to compressed read-only DMG
hdiutil convert "${DMG_RW}" -format UDZO -o "${DMG}"
rm -f "${DMG_RW}"
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
        --target "master" \
        --title "${TAG} — MiMiNavigator (notarized)" \
        --notes-file "Scripts/release_notes_${VERSION}.md"
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
