#!/bin/zsh

# Build and install MiMiNavigator
# This script compiles the project and installs the app into ~/Applications

set -e

# скрипт сразу падает при любой ошибке, вместо тихого развала где-нибудь на середине.
set -euo pipefail

/Users/senat/Develop/MiMiNavigator/Scripts/refreshVersionFile.zsh

PROJECT_DIR="/Users/senat/Develop/MiMiNavigator"
DERIVED_DATA="/tmp/mimi_build"
APP_NAME="MiMiNavigator.app"
TARGET_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME"
INSTALL_DIR="$HOME/Applications"

echo "==> Building project"

cd "$PROJECT_DIR"

xcodebuild \
  -project MiMiNavigator.xcodeproj \
  -scheme MiMiNavigator \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED=YES

echo "==> Removing quarantine attributes"
xattr -cr "$TARGET_APP"

echo "==> Removing previous installation"
rm -rf "$INSTALL_DIR/$APP_NAME"

echo "==> Installing new build"
mv "$TARGET_APP" "$INSTALL_DIR"

echo "==> Cleaning build directory"
rm -rf "$DERIVED_DATA"

echo "==> Done. App installed to $INSTALL_DIR/$APP_NAME"