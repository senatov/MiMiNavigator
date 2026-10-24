#!/bin/zsh
# MARK: - Verify Release Bundle
# Reject a release whose app version or macOS deployment target differs from policy.
set -euo pipefail

fail() {
    print -u2 "❌ Release bundle check: $1"
    exit 1
}

if (( $# != 2 )); then
    fail "usage: zsh Scripts/verify_release_bundle.zsh <app-path> <version>"
fi

app="$1"
version="$2"
plist="${app}/Contents/Info.plist"
binary="${app}/Contents/MacOS/MiMiNavigator"
[[ "${version}" =~ '^[0-9]+\.[0-9]\.[0-9]\.[0-9]$' ]] || fail "invalid four-component version: ${version}"
[[ -f "${plist}" ]] || fail "missing Info.plist: ${plist}"
[[ -f "${binary}" ]] || fail "missing executable: ${binary}"

bundle_version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "${plist}" 2>/dev/null)" || fail "missing CFBundleShortVersionString"
declared_minimum="$(/usr/bin/plutil -extract LSMinimumSystemVersion raw -o - "${plist}" 2>/dev/null)" || fail "missing LSMinimumSystemVersion"
binary_build="$(xcrun vtool -show-build "${binary}" 2>/dev/null)" || fail "cannot read executable deployment target"
binary_minimum="$(print -r -- "${binary_build}" | /usr/bin/awk '$1 == "minos" { print $2; count++ } END { if (count != 1) exit 1 }')" || fail "missing or ambiguous executable deployment target"

if [[ "${version}" == "0.9.1.2" ]]; then
    expected_minimum="26.0"
else
    expected_minimum="27.0"
fi

[[ "${bundle_version}" == "${version}" ]] || fail "app version ${bundle_version} differs from release ${version}"
[[ "${declared_minimum}" == "${expected_minimum}" ]] || fail "Info.plist requires macOS ${declared_minimum}; release ${version} must require ${expected_minimum}"
[[ "${binary_minimum}" == "${expected_minimum}" ]] || fail "executable requires macOS ${binary_minimum}; release ${version} must require ${expected_minimum}"
print "   Release bundle: version ${bundle_version}, minimum macOS ${expected_minimum} (Info.plist and executable)"
