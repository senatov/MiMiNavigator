#!/bin/zsh
# clean_strange_attr.zsh — strip junk xattrs (quarantine, FinderInfo, ResourceFork)
# Usage:  zsh Scripts/clean_strange_attr.zsh [--list | --clean]
#   (no flag) = interactive confirm
#   --list    = show dirty files, no changes
#   --clean   = remove without asking

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
MODE="${1:-}"
export LC_ALL=C

# attrs to kill — only junk ones, never touch signing/dates/etc
JUNK_ATTRS=(
    com.apple.FinderInfo
    com.apple.ResourceFork
    com.apple.quarantine
)
ATTR_REGEX='com\.apple\.(FinderInfo|ResourceFork|quarantine)'

# dirs to skip — no point scanning these
PRUNE_DIRS=(.git .build DerivedData .spm-checkouts node_modules .swiftpm)

# build find prune expression
PRUNE_EXPR=""
for d in "${PRUNE_DIRS[@]}"; do
    PRUNE_EXPR="${PRUNE_EXPR} -name ${d} -prune -o"
done

echo "🔍 Scanning: ${PROJECT_ROOT}"
echo "   Pattern: ${ATTR_REGEX}"
echo "   Skipping: ${PRUNE_DIRS[*]}"
echo ""

# collect dirty files — fast: xattr (no flags) is cheaper than xattr -l
typeset -a DIRTY
typeset -A FILE_ATTRS   # file -> "attr1 attr2"
DIRTY=()

while IFS= read -r -d '' f; do
    # quick check: any xattrs at all?
    RAW=$(xattr "$f" 2>/dev/null) || continue
    [[ -z "$RAW" ]] && continue
    # filter to junk only
    MATCHED=""
    for attr in "${JUNK_ATTRS[@]}"; do
        if echo "$RAW" | grep -qF "$attr"; then
            MATCHED="${MATCHED} ${attr}"
        fi
    done
    if [[ -n "$MATCHED" ]]; then
        DIRTY+=("$f")
        FILE_ATTRS[$f]="${MATCHED}"
    fi
done < <(eval "find '${PROJECT_ROOT}' ${PRUNE_EXPR} -type f -print0 2>/dev/null")

COUNT=${#DIRTY[@]}

if (( COUNT == 0 )); then
    echo "✅ No junk xattrs found."
    exit 0
fi

echo "⚠️  ${COUNT} file(s) with junk xattrs:"
for f in "${DIRTY[@]}"; do
    echo "   ${f##${PROJECT_ROOT}/} →${FILE_ATTRS[$f]}"
done
echo ""

# --list: stop here
[[ "${MODE}" == "--list" ]] && { echo "ℹ️  List mode — no changes."; exit 0; }

# interactive confirm unless --clean
if [[ "${MODE}" != "--clean" ]]; then
    read "reply?Remove these attrs? (y/N) "
    [[ ! "$reply" =~ ^[Yy]$ ]] && { echo "❌ Skipped."; exit 0; }
fi

# surgical removal — only junk attrs, not xattr -c
echo "🧹 Removing junk xattrs..."
REMOVED=0
FAILED=0
for f in "${DIRTY[@]}"; do
    for attr in "${JUNK_ATTRS[@]}"; do
        if xattr "$f" 2>/dev/null | grep -qF "$attr"; then
            if xattr -d "$attr" "$f" 2>/dev/null; then
                (( REMOVED++ ))
            else
                (( FAILED++ ))
                echo "   ⚠️  failed: ${f##${PROJECT_ROOT}/} (${attr})"
            fi
        fi
    done
done

echo ""
echo "✅ Done: removed ${REMOVED} attr(s), failed ${FAILED}."
