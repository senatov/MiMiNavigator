#!/bin/zsh
# home_cleanup.zsh — Remove junk files from $HOME
# Run periodically or before commits.
# All comments in English.

set -uo pipefail

echo "═══════════════════════════════════════════"
echo "  Home Cleanup — $(whoami)@$(hostname -s)"
echo "═══════════════════════════════════════════"
echo ""

DELETED=0

# 1. Crashed zsh history fragments (.!NNNNN!.zsh_history)
for f in "$HOME"/.!*!.zsh_history(N); do
    echo "🗑  Removing crashed zsh history: ${f:t}"
    rm -f "$f"
    ((DELETED++))
done

# 2. macOS .DS_Store in home root
if [[ -f "$HOME/.DS_Store" ]]; then
    echo "🗑  Removing ~/.DS_Store"
    rm -f "$HOME/.DS_Store"
    ((DELETED++))
fi

# 3. macOS Finder metadata in home root
for f in "$HOME"/._*(N); do
    echo "🗑  Removing Finder metadata: ${f:t}"
    rm -f "$f"
    ((DELETED++))
done

# 4. Stale .CFUserTextEncoding backup
for f in "$HOME"/.CFUserTextEncoding.*(N); do
    echo "🗑  Removing stale CFUserTextEncoding backup: ${f:t}"
    rm -f "$f"
    ((DELETED++))
done

# 5. Empty .localized files in home
if [[ -f "$HOME/.localized" ]]; then
    echo "🗑  Removing ~/.localized"
    rm -f "$HOME/.localized"
    ((DELETED++))
fi

# 6. Xcode DerivedData older than 14 days
DD_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DD_DIR" ]]; then
    OLD_DD=$(find "$DD_DIR" -maxdepth 1 -mindepth 1 -type d -mtime +14 2>/dev/null)
    if [[ -n "$OLD_DD" ]]; then
        COUNT=$(echo "$OLD_DD" | wc -l | tr -d ' ')
        echo "🗑  Removing $COUNT stale DerivedData folders (>14 days)"
        echo "$OLD_DD" | while read -r d; do
            echo "   ↳ ${d:t}"
            rm -rf "$d"
            ((DELETED++))
        done
    fi
fi

# 7. Xcode old archives older than 90 days
ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives"
if [[ -d "$ARCHIVES_DIR" ]]; then
    OLD_ARCH=$(find "$ARCHIVES_DIR" -maxdepth 2 -name '*.xcarchive' -mtime +90 2>/dev/null)
    if [[ -n "$OLD_ARCH" ]]; then
        COUNT=$(echo "$OLD_ARCH" | wc -l | tr -d ' ')
        echo "🗑  Removing $COUNT old Xcode archives (>90 days)"
        echo "$OLD_ARCH" | while read -r a; do
            echo "   ↳ ${a:t}"
            rm -rf "$a"
            ((DELETED++))
        done
    fi
fi

# 8. Core dumps
for f in /cores/core.*(N); do
    echo "🗑  Removing core dump: ${f:t}"
    rm -f "$f"
    ((DELETED++))
done

# 9. Stale .swp / .swo vim swap files in home
for f in "$HOME"/.*.sw[op](N); do
    echo "🗑  Removing vim swap: ${f:t}"
    rm -f "$f"
    ((DELETED++))
done

# 10. Crash reports older than 30 days
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if [[ -d "$CRASH_DIR" ]]; then
    OLD_CRASH=$(find "$CRASH_DIR" -type f -mtime +30 2>/dev/null)
    if [[ -n "$OLD_CRASH" ]]; then
        COUNT=$(echo "$OLD_CRASH" | wc -l | tr -d ' ')
        echo "🗑  Removing $COUNT old crash reports (>30 days)"
        echo "$OLD_CRASH" | xargs rm -f
        DELETED=$((DELETED + COUNT))
    fi
fi

echo ""
echo "═══════════════════════════════════════════"
if ((DELETED > 0)); then
    echo "  ✅ Cleaned $DELETED item(s)"
else
    echo "  ✨ Nothing to clean — home is tidy"
fi
echo "═══════════════════════════════════════════"
