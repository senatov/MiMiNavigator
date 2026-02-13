#!/bin/zsh
# git_cleanup.zsh — Clean up .git directory: prune, gc, compress
# Run from: /Users/senat/Develop/MiMiNavigator/Scripts/
# All comments in English.

set -euo pipefail

# Resolve project root (directory above Scripts/)
SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "═══════════════════════════════════════════"
echo "  Git Cleanup — $(basename "${PROJECT_ROOT}")"
echo "═══════════════════════════════════════════"
echo ""

# Verify we're in a git repo
if [[ ! -d .git ]]; then
    echo "❌ ERROR: No .git directory found in ${PROJECT_ROOT}"
    exit 1
fi

# Show current branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
echo "📌 Branch: ${BRANCH}"

# Size before
SIZE_BEFORE=$(du -sh .git | cut -f1)
echo "📦 .git size before: ${SIZE_BEFORE}"
echo ""

# Step 1: Remove stale remote tracking branches
echo "🔹 Step 1/5: Pruning stale remote branches..."
git remote prune origin 2>/dev/null || echo "   ⚠️  No remote 'origin' or nothing to prune"

# Step 2: Remove orphaned worktrees
echo "🔹 Step 2/5: Pruning worktrees..."
git worktree prune 2>/dev/null || true

# Step 3: Expire reflog
echo "🔹 Step 3/5: Expiring reflog (older than 30 days)..."
git reflog expire --expire=30.days --all

# Step 4: Aggressive garbage collection
echo "🔹 Step 4/5: Running aggressive garbage collection..."
git gc --aggressive --prune=now

# Step 5: Repack for optimal compression
echo "🔹 Step 5/5: Repacking objects..."
git repack -a -d --depth=250 --window=250

echo ""

# Size after
SIZE_AFTER=$(du -sh .git | cut -f1)
echo "═══════════════════════════════════════════"
echo "  📦 Before: ${SIZE_BEFORE}"
echo "  📦 After:  ${SIZE_AFTER}"
echo "═══════════════════════════════════════════"

# Show stats
echo ""
echo "📊 Repository stats:"
echo "   Objects: $(git count-objects -v 2>/dev/null | grep 'count:' | awk '{print $2}')"
echo "   Packs:   $(git count-objects -v 2>/dev/null | grep 'in-pack:' | awk '{print $2}')"
echo "   Loose:   $(git count-objects -v 2>/dev/null | grep 'size:' | head -1 | awk '{print $2}') KB"
echo ""
echo "✅ Git cleanup complete."
