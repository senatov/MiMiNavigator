#!/bin/zsh
# MARK: - Verify the app without private source packages
set -euo pipefail
cd "${0:A:h:h}"
python3 Scripts/BinaryPackages/configure.py --verify
verification="$PWD/build/binary-packages/verification"
[[ ! -e "$verification/Packages" ]]
xcodebuild -project "$verification/MiMiNavigator.xcodeproj" \
    -scheme MiMiNavigator -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath "$PWD/build/binary-packages/DerivedData" \
    ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
