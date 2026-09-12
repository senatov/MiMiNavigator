#!/bin/zsh
# MARK: - Opt into private source packages for maintainer development
set -euo pipefail
cd "${0:A:h:h}"
[[ -f Packages/LogKit/Package.swift ]] || {
    print -u2 'Private sources are missing. Initialize Packages with an authorized GitHub account.'
    exit 1
}
python3 - <<'PY'
from pathlib import Path
project = Path('MiMiNavigator.xcodeproj/project.pbxproj')
project.write_text(project.read_text().replace('BinaryPackages/', 'Packages/'))
PY
print 'Using private source packages. Do not commit this local project override.'
