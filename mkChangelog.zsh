#!/bin/bash

cd /Users/senat/Develop/MMNavigator || exit 1

echo "# Changelog" > CHANGELOG.md
echo "" >> CHANGELOG.md
echo "All notable changes to this project will be documented in this file." >> CHANGELOG.md
echo "" >> CHANGELOG.md

git log --date=short --pretty=format:'## [%ad] - %an%n- %s%n' >> CHANGELOG.md

echo "✅ CHANGELOG.md успешно сгенерирован!"