#!/bin/zsh

set -e

Scripts/refreshVersionFile.zsh

BUILD=/tmp/mimi_build
DMG=/tmp/MiMiNavigator.dmg

rm -rf $BUILD

xcodebuild \
-project MiMiNavigator.xcodeproj \
-scheme MiMiNavigator \
-configuration Release \
-derivedDataPath $BUILD \
build

APP="$BUILD/Build/Products/Release/MiMiNavigator.app"

xattr -cr "$APP"

TMP=/tmp/mimi_dmg
rm -rf $TMP
mkdir $TMP
cp -R "$APP" $TMP/

hdiutil create \
-volname "MiMiNavigator" \
-srcfolder $TMP \
-ov \
-format UDZO \
$DMG

echo "DMG created: $DMG"