#!/bin/zsh
# MARK: - Rebuild private MiMiKits and verify the source-free application
set -euo pipefail
cd "${0:A:h:h}"
[[ -f Packages/ArchiveKit/Package.swift ]] || {
    print -u2 'Private MiMiKits sources are missing from Packages.'
    exit 1
}
print 'Building private MiMiKits XCFramework artifacts...'
zsh Scripts/build_binary_packages.zsh
print 'Building the application from local source-free binary wrappers...'
zsh Scripts/verify_binary_packages.zsh
print 'Private MiMiKits rebuild and source-free application verification succeeded.'
