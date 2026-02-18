#!/usr/bin/env zsh
# squash_to.zsh — squash all commits after given commit ID into one
#
# Usage:  zsh Scripts/squash_to.zsh <commit-id> [commit message]
#
# Example:
#   zsh Scripts/squash_to.zsh eef838e
#   zsh Scripts/squash_to.zsh eef838e "feat: my combined commit message"

set -e

TARGET=$1
MSG=${2:-""}

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ -z "$TARGET" ]]; then
    echo "❌  Usage: zsh Scripts/squash_to.zsh <commit-id> [message]"
    exit 1
fi

# Resolve full SHA (works with 7-char short IDs)
FULL_SHA=$(git rev-parse --verify "$TARGET^{commit}" 2>/dev/null) || {
    echo "❌  Commit '$TARGET' not found"
    exit 1
}

# Count commits to be squashed
COUNT=$(git log --oneline "${FULL_SHA}..HEAD" | wc -l | tr -d ' ')

if [[ $COUNT -eq 0 ]]; then
    echo "⚠️   Nothing to squash — no commits after $TARGET"
    exit 0
fi

echo "📦  Squashing $COUNT commit(s) after $TARGET:"
git log --oneline "${FULL_SHA}..HEAD"
echo ""

# ── Build commit message ──────────────────────────────────────────────────────
if [[ -z "$MSG" ]]; then
    # Auto-collect all commit messages
    MSG=$(git log --format="%s" "${FULL_SHA}..HEAD" | tail -r | paste -sd $'\n')
    echo "📝  Auto-generated message:"
    echo "$MSG"
    echo ""
fi

# ── Warn if any commits are already pushed ───────────────────────────────────
REMOTE=$(git remote 2>/dev/null | head -1)
if [[ -n "$REMOTE" ]]; then
    PUSHED=$(git log --oneline "${FULL_SHA}..HEAD" | while read line; do
        sha=$(echo $line | cut -d' ' -f1)
        git branch -r --contains "$sha" 2>/dev/null | grep -v HEAD | head -1
    done | grep -c . || true)
    if [[ $PUSHED -gt 0 ]]; then
        echo "⚠️   WARNING: some of these commits are already pushed to remote!"
        echo "    Squashing will require 'git push --force' afterwards."
        echo "    Only safe if you are the sole developer on this branch."
        echo ""
    fi
fi


echo -n "❓  Squash $COUNT commit(s) into one? [y/N] "
read CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🚫  Aborted"
    exit 0
fi

# ── Do the squash ─────────────────────────────────────────────────────────────
git reset --soft "$FULL_SHA"
git commit -m "$MSG"

echo ""
echo "✅  Done. Result:"
git log --oneline -5
