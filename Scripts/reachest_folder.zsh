#!/bin/zsh
# Author: ChatGPT
# Purpose: Create a report with folders containing the most direct child elements.


set -u

readonly TARGET_ROOT="${1:-/}"
readonly OUTPUT_FILE="/Users/senat/Downloads/_reachest_folder.txt"
readonly MAX_RESULTS="${MAX_RESULTS:-200}"
readonly TEMP_FILE="$(mktemp /tmp/reachest_folders.XXXXXX)"
cleanup() {

    rm -f "$TEMP_FILE"

}
trap cleanup EXIT
mkdir -p "$(dirname "$OUTPUT_FILE")"
{
    echo "Reachest folders by direct child count"
    echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Target root: $TARGET_ROOT"
    echo "Max results: $MAX_RESULTS"
    echo
    echo "Scanning may skip protected folders because macOS enjoys cosplaying a prison warden."
    echo
    printf "%10s  %s\n" "COUNT" "FOLDER"
    printf "%10s  %s\n" "----------" "------------------------------------------------------------"

} > "$OUTPUT_FILE"

find "$TARGET_ROOT" -xdev -type d 2>/dev/null | while IFS= read -r folder; do
    count="$(find "$folder" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
    printf "%10d  %s\n" "$count" "$folder" >> "$TEMP_FILE"

done
sort -nr "$TEMP_FILE" | head -n "$MAX_RESULTS" >> "$OUTPUT_FILE"
echo "Report created: $OUTPUT_FILE"
