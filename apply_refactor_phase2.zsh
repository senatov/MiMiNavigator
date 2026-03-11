#!/bin/zsh
# apply_refactor_phase2.zsh — Apply AppState & Settings splits
# Run from ~/Develop/MiMiNavigator AFTER phase 1
set -euo pipefail

cd ~/Develop/MiMiNavigator || { echo "❌ Can't cd to project"; exit 1; }

echo "🔧 Phase 2: Splitting god-files..."

# ── 1. Remove old SettingsPanes.swift (replaced by 8 smaller files) ──
echo "📂 Splitting SettingsPanes.swift (1043 lines) → 8 files..."
rm -f GUI/Sources/Settings/SettingsPanes.swift

# ── 2. Extract refactor_phase2.tar.gz ──
echo "📦 Extracting new files..."
tar xzf refactor_phase2.tar.gz

echo ""
echo "✅ Phase 2 applied."
echo ""
echo "Files created/replaced:"
echo "  AppState/"
echo "    AppState.swift         (124 lines — core only)"
echo "    AppState+Navigation.swift"
echo "    AppState+Refresh.swift"
echo "    AppState+Archive.swift"
echo "    AppState+Marks.swift"
echo "    AppState+Selection.swift (selection, file ops, data access, lifecycle, search)"
echo ""
echo "  Settings/"
echo "    SettingsHelpers.swift      (shared SettingsRow, SettingsGroupBox)"
echo "    SettingsGeneralPane.swift"
echo "    SettingsPanelsPane.swift"
echo "    SettingsTabsPane.swift"
echo "    SettingsArchivesPane.swift"
echo "    SettingsNetworkPane.swift"
echo "    SettingsDiffToolPane.swift (includes DiffToolEditSheet)"
echo "    SettingsHotkeysPane.swift"
echo "    SettingsColorsPane.swift   (trimmed, -146 lines)"
echo ""
echo "  Config/"
echo "    ColorThemeStore.swift      (extracted from SettingsColorsPane)"
echo ""
echo "⚠️  SettingsHelpers: SettingsRow and SettingsGroupBox changed from private → internal."
echo "    If compile issues, check accessibility."
