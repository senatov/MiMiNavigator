#!/bin/zsh
# UTF-8 with BOM

# Scan and remove unwanted extended attributes in the project
# Targets FinderInfo, ResourceFork, and quarantine flags

echo "🔍 Scanning for unwanted extended attributes in $(pwd)..."

# Find files with matching xattr and list them
dirty_files=()
while IFS= read -r file; do
    dirty_files+=("$file")
done < <(
    find . -type f -exec xattr -l {} 2>/dev/null \; \
    | grep -E "com.apple.(FinderInfo|ResourceFork|quarantine)" -B1 \
    | grep -vE "^(com.apple.|--)$"
)

if [[ ${#dirty_files[@]} -eq 0 ]]; then
    echo "✅ No files with FinderInfo, ResourceFork, or quarantine attributes found."
    exit 0
fi

echo "⚠️ Found ${#dirty_files[@]} file(s) with unwanted attributes:"
printf '%s\n' "${dirty_files[@]}"

echo
read "reply?Do you want to remove these attributes? (y/N) "
if [[ "$reply" =~ ^[Yy]$ ]]; then
    for f in "${dirty_files[@]}"; do
        echo "🧹 Cleaning: $f"
        xattr -c "$f" 2>/dev/null
    done
    echo "✅ All unwanted attributes removed."
else
    echo "❌ Cleanup skipped."
fi