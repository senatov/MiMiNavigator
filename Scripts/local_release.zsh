#!/bin/zsh

set -e

cd ~/Develop/MiMiNavigator

git add .
git commit -m "build update"
git push

xcodebuild \
-project MiMiNavigator.xcodeproj \
-scheme MiMiNavigator \
-configuration Release \
-derivedDataPath build

APP="build/Build/Products/Release/MiMiNavigator.app"

xattr -cr "$APP"

mkdir -p dmg
rm -rf dmg/*
cp -R "$APP" dmg/

hdiutil create \
-volname "MiMiNavigator" \
-srcfolder dmg \
-ov \
-format UDZO \
MiMiNavigator.dmg

echo "DMG created:"
ls -lh MiMiNavigator.dmg