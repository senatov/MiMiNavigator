#!/bin/zsh
# MARK: - Build distributable private libraries on the maintainer's Mac
set -euo pipefail
cd "${0:A:h:h}"
zsh Scripts/stamp_version.zsh
python3 Scripts/BinaryPackages/build.py prepare
swift build --build-system native --package-path build/binary-packages/work -c release --arch arm64
python3 Scripts/BinaryPackages/build.py package
