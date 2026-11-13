#!/bin/zsh
# MARK: - Fetch missing pinned SwiftPM revisions
# Refresh existing repository caches without changing Package.resolved.

set -euo pipefail

if (( $# != 3 )); then
    print -u2 "Usage: $0 <Package.resolved> <SourcePackages directory> <resolver log>"
    exit 2
fi

resolved_file="$1"
source_packages_dir="$2"
failure_log="$3"
if [[ ! -f "${resolved_file}" ]]; then
    print -u2 "Package pins not found: ${resolved_file}"
    exit 1
fi
if [[ ! -f "${failure_log}" ]]; then
    print -u2 "Package resolver log not found: ${failure_log}"
    exit 1
fi

fetched_count=0
while IFS=$'\t' read -r package_url revision version; do
    [[ -n "${package_url}" && -n "${revision}" ]] || continue
    repository_name="${package_url:t}"
    repository_name="${repository_name%.git}"
    for repository_path in "${source_packages_dir}/repositories/${repository_name}-"*(N/); do
        repository_suffix="${repository_path:t}"
        repository_suffix="${repository_suffix#${repository_name}-}"
        [[ "${repository_suffix}" =~ '^[[:xdigit:]]+$' ]] || continue
        repository_url="$(git -C "${repository_path}" config --get remote.origin.url || true)"
        [[ "${repository_url%.git}" == "${package_url%.git}" ]] || continue
        if git -C "${repository_path}" cat-file -e "${revision}^{tree}" 2>/dev/null; then
            continue
        fi
        print "   Fetching pinned ${repository_name} revision ${revision[1,12]}..."
        if [[ -n "${version}" ]]; then
            git -C "${repository_path}" fetch --quiet --no-tags origin "refs/tags/${version}" || true
        fi
        if ! git -C "${repository_path}" cat-file -e "${revision}^{tree}" 2>/dev/null; then
            git -C "${repository_path}" fetch --quiet --no-tags origin "${revision}"
        fi
        if ! git -C "${repository_path}" cat-file -e "${revision}^{tree}" 2>/dev/null; then
            print -u2 "   Pinned tree is unavailable after fetch: ${repository_name} ${revision}"
            exit 1
        fi
        (( fetched_count += 1 ))
    done
done < <(python3 - "${resolved_file}" "${failure_log}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    pins = json.load(file).get("pins", [])
with open(sys.argv[2], encoding="utf-8", errors="replace") as file:
    failure_text = file.read()
for pin in pins:
    location = pin.get("location", "")
    revision = pin.get("state", {}).get("revision", "")
    version = pin.get("state", {}).get("version", "")
    if location.startswith("https://") and revision and revision in failure_text:
        print(f"{location}\t{revision}\t{version}")
PY
)
(( fetched_count > 0 ))
