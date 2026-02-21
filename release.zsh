#!/usr/bin/env zsh
# release.zsh — build, sign, (optionally notarize), upload to GitHub release
# Usage:
#   ./release.zsh              — Developer ID, no notarize
#   ./release.zsh --notarize   — Developer ID + notarize (needs AC_PASSWORD in env or Keychain)
#
# Prerequisites:
#   brew install gh
#   gh auth login
#   For notarize: export AC_PASSWORD="xxxx-xxxx-xxxx-xxxx"  (app-specific password)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCHEME="MiMiNavigator"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE_PATH="$PROJECT_DIR/build/MiMiNavigator.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/export"
APP_NAME="MiMiNavigator"
TEAM_ID="G2V9T9AD95"
APPLE_ID="iakov.senatov@gmail.com"   # ← change if needed

NOTARIZE=false
[[ "${1:-}" == "--notarize" ]] && NOTARIZE=true

# ── Version ───────────────────────────────────────────────────────────────────
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_DIR/MiMiNavigator.xcodeproj/project.pbxproj" \
  | head -1 | sed 's/.*= //;s/;//;s/ //')
echo "▶ Version: $VERSION"
TAG="v$VERSION"

# ── Clean previous build ──────────────────────────────────────────────────────
rm -rf "$PROJECT_DIR/build/export" "$ARCHIVE_PATH"
echo "▶ Cleaned build dir"

# ── Archive ───────────────────────────────────────────────────────────────────
echo "▶ Archiving…"
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  | tail -5

# ── ExportOptions.plist ───────────────────────────────────────────────────────
cat > "$PROJECT_DIR/build/ExportOptions.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
PLIST

# ── Export .app ───────────────────────────────────────────────────────────────
echo "▶ Exporting .app…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$PROJECT_DIR/build/ExportOptions.plist" \
  | tail -5

APP_PATH="$EXPORT_PATH/$APP_NAME.app"
echo "▶ App: $APP_PATH"

# ── Notarize (optional) ───────────────────────────────────────────────────────
if $NOTARIZE; then
  echo "▶ Zipping for notarization…"
  ditto -c -k --keepParent "$APP_PATH" "$EXPORT_PATH/${APP_NAME}_notarize.zip"

  echo "▶ Submitting to Apple notarization service…"
  xcrun notarytool submit "$EXPORT_PATH/${APP_NAME}_notarize.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "${AC_PASSWORD:?Set AC_PASSWORD env var or use --password}" \
    --wait \
    --timeout 600

  echo "▶ Stapling ticket…"
  xcrun stapler staple "$APP_PATH"
  echo "▶ Notarization complete"
fi

# ── Create DMG or zip ─────────────────────────────────────────────────────────
ARTIFACT="$PROJECT_DIR/build/${APP_NAME}-${VERSION}.zip"
echo "▶ Creating $ARTIFACT…"
ditto -c -k --keepParent "$APP_PATH" "$ARTIFACT"
echo "▶ Size: $(du -sh "$ARTIFACT" | cut -f1)"

# ── Upload to GitHub release ──────────────────────────────────────────────────
echo "▶ Uploading to GitHub release $TAG…"
gh release upload "$TAG" "$ARTIFACT" --clobber

echo ""
echo "✅ Done! https://github.com/senatov/MiMiNavigator/releases/tag/$TAG"
