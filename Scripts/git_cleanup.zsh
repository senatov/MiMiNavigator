#!/bin/zsh
# git_cleanup.zsh — pre-commit hygiene: prune, gc, check for junk.
# Usage:  zsh Scripts/git_cleanup.zsh [-v]
# -v = verbose (show large files, merged branches list)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${PROJECT_ROOT}/Packages"
VERBOSE=false
[[ "${1:-}" == "-v" ]] && VERBOSE=true

cd "${PROJECT_ROOT}"

echo "═══════════════════════════════════════════"
echo "  Git Cleanup — $(basename "${PROJECT_ROOT}")"
echo "═══════════════════════════════════════════"
echo ""

[[ ! -d .git ]] && { echo "❌ No .git in ${PROJECT_ROOT}"; exit 1; }

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
echo "📌 Branch: ${BRANCH}"
SIZE_BEFORE=$(du -sh .git | cut -f1)
echo "📦 .git size before: ${SIZE_BEFORE}"
echo ""
# ── Step 1: Warn about uncommitted changes ────────────────────────────────────
echo "🔹 Step 1/7: Checking working tree..."
DIRTY_COUNT=$(git status --porcelain | wc -l | tr -d ' ')
if (( DIRTY_COUNT > 0 )); then
    echo "   ⚠️  ${DIRTY_COUNT} uncommitted change(s) — will be preserved"
    $VERBOSE && git status --short | head -15
else
    echo "   ✓ working tree clean"
fi

# ── Step 2: Prune stale remote branches ───────────────────────────────────────
echo "🔹 Step 2/7: Pruning stale remote branches..."
git remote prune origin 2>/dev/null || echo "   ⚠️  no remote 'origin'"

# ── Step 3: Delete merged local branches (except current + master/main) ───────
echo "🔹 Step 3/7: Cleaning merged branches..."
MERGED=$(git branch --merged HEAD 2>/dev/null \
    | grep -vE '^\*|^\s*(master|main|develop)$' \
    | tr -d ' ' || true)
if [[ -n "${MERGED}" ]]; then
    echo "   removing: ${MERGED}"
    echo "${MERGED}" | xargs git branch -d 2>/dev/null || true
else
    echo "   ✓ no merged branches to remove"
fi

# ── Step 4: Prune worktrees + reflog ─────────────────────────────────────────
echo "🔹 Step 4/7: Pruning worktrees + reflog (>30 days)..."
git worktree prune 2>/dev/null || true
git reflog expire --expire=30.days --all 2>/dev/null

# ── Step 5: GC (aggressive already includes repack) ───────────────────────────
echo "🔹 Step 5/7: Garbage collection..."
git gc --aggressive --prune=now 2>&1 | grep -v "^$" || true

# ── Step 6: Packages submodule cleanup ────────────────────────────────────────
echo "🔹 Step 6/7: Packages submodule cleanup..."
if [[ -d "${PACKAGES_DIR}/.git" ]]; then
    (cd "${PACKAGES_DIR}" && git gc --prune=now 2>/dev/null && echo "   ✓ Packages gc done") || echo "   ⚠️  Packages gc skipped"
else
    echo "   ⚠️  Packages not a git repo — skipping"
fi

# ── Step 7: Large file check (verbose only) ──────────────────────────────────
if $VERBOSE; then
    echo "🔹 Step 7/7: Largest tracked files..."
    git ls-files -z | xargs -0 -I{} du -sh {} 2>/dev/null \
        | sort -rh | head -10
    echo ""
else
    echo "🔹 Step 7/7: (use -v for large file report)"
fi

echo ""
SIZE_AFTER=$(du -sh .git | cut -f1)
echo "═══════════════════════════════════════════"
echo "  📦 Before: ${SIZE_BEFORE}"
echo "  📦 After:  ${SIZE_AFTER}"
echo "═══════════════════════════════════════════"

echo ""
echo "📊 Repository stats:"
STATS=$(git count-objects -v 2>/dev/null)
echo "   Objects: $(echo "${STATS}" | awk '/^count:/{print $2}')"
echo "   Packs:   $(echo "${STATS}" | awk '/^in-pack:/{print $2}')"
echo "   Loose:   $(echo "${STATS}" | awk '/^size:/{print $2; exit}') KB"
echo ""
echo "✅ Git cleanup complete."
