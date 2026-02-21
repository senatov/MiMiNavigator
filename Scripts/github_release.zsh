#!/usr/bin/env zsh
# github_release.zsh — zip MiMiNavigator.app from xcarchive and upload to GitHub release
# Usage: ./Scripts/github_release.zsh 0.9.3.2
#
# Prerequisites:
#   brew install gh && gh auth login

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  print -u2 "Usage: $0 <version>   e.g. $0 0.9.3.2"
  exit 1
fi

VERSION="$1"
TAG="v${VERSION}"

# ── Paths ─────────────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$PROJECT_DIR/build/MiMiNavigator.xcarchive"
APP="$ARCHIVE/Products/Applications/MiMiNavigator.app"
ZIP="$PROJECT_DIR/build/MiMiNavigator-${VERSION}.zip"

# ── Checks ────────────────────────────────────────────────────────────────────
if [[ ! -d "$APP" ]]; then
  print -u2 "❌ App not found: $APP"
  print -u2 "   Run Product → Archive in Xcode first, or: xcodebuild archive …"
  exit 1
fi

if ! command -v gh &>/dev/null; then
  print -u2 "❌ gh not found. Install: brew install gh && gh auth login"
  exit 1
fi

# ── Zip ───────────────────────────────────────────────────────────────────────
echo "▶ Zipping $APP …"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "   → $ZIP ($(du -sh "$ZIP" | cut -f1))"

# ── Upload ────────────────────────────────────────────────────────────────────
echo "▶ Uploading to GitHub release $TAG …"
gh release upload "$TAG" "$ZIP" --clobber

echo ""
echo "✅ https://github.com/senatov/MiMiNavigator/releases/tag/$TAG"
