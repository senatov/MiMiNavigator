#!/usr/bin/env zsh
# stamp_version.zsh — thin wrapper, delegates to refreshVersionFile.zsh
# Usage: zsh Scripts/stamp_version.zsh

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
exec zsh "$SCRIPT_DIR/refreshVersionFile.zsh" "$@"
