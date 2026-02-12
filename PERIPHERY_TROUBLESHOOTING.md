Periphery Troubleshooting Guide
Problem: DecodingError with shellScript
Error Description
error: (DecodingError) typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "objects", intValue: nil), _DictionaryCodingKey(stringValue: "977B59492EDF6F9700F7F80F", intValue: nil), CodingKeys(stringValue: "shellScript", intValue: nil)], debugDescription: "Expected to decode String but found an array instead.", underlyingError: nil))
This error occurs when an Xcode project contains a Build Phase Script that uses an array of strings for shellScript instead of a single string. Periphery expects a string and cannot decode an array.
Solutions
Solution 1: Update Periphery (Recommended)
Newer versions of Periphery have fixed this issue:
# Upgrade via Homebrew
brew upgrade peripheryapp/periphery/periphery

# Check version (must be >= 2.19.0)
periphery version

# Run again
periphery scan --config .periphery.yml
Solution 2: Use skip_build
I have already updated .periphery.yml with these settings:
clean_build: false
skip_build: true    # Skips the build phase
Usage:
# First perform a clean build of the project in Xcode
# ⌘⇧K (Clean Build Folder) + ⌘B (Build)

# Then run Periphery
periphery scan --config .periphery.yml
Pros: Faster for repeated runs
Cons: Requires building the project beforehand
Solution 3: Use Index-Based Analysis
I created an alternative configuration .periphery-index.yml:
# First build the project with indexing enabled
xcodebuild -scheme MiMiNavigator \
-configuration Debug \
-destination 'platform=macOS' \
-derivedDataPath .build \
build

# Run Periphery with the index configuration
periphery scan --config .periphery-index.yml
Solution 4: Fix the Xcode Project (Manual)
If you want to fix the issue directly in the project:
Open the project in Xcode
Select the MiMiNavigator target
Go to Build Phases
Locate the Run Script phases (usually SwiftLint or SwiftFormat)
If the script is multiline, combine it into a single string
Or manually edit project.pbxproj:
# Locate the problematic script (ID: 977B59492EDF6F9700F7F80F)
grep -A 10 "977B59492EDF6F9700F7F80F" MiMiNavigator.xcodeproj/project.pbxproj

# Change the format from array to string:
# BEFORE:
# shellScript = (
#   "line1",
#   "line2",
# );

# AFTER:
# shellScript = "line1\nline2\n";
⚠️ Warning: Manually editing project.pbxproj can break the project. Make a backup first.
Recommended Order of Actions
Try Solution 2 (skip_build) – simplest option:
# In Xcode: ⌘⇧K + ⌘B
periphery scan --config .periphery.yml
If that doesn’t work, update Periphery (Solution 1):
brew upgrade peripheryapp/periphery/periphery
periphery scan --config .periphery.yml
If the problem persists, use index-based analysis (Solution 3).
Additional Information
Check Periphery Version
periphery version
Full Reinstallation of Periphery
brew uninstall periphery
brew install peripheryapp/periphery/periphery
Alternative Configurations
You have two configurations:
.periphery.yml – main (with skip_build: true)
.periphery-index.yml – index-based (for complex cases)
Known Issues
This error often occurs with SwiftLint/SwiftFormat scripts
The issue was fixed in Periphery 2.19.0+
The skip_build workaround works for most projects
Useful Links
Periphery GitHub Issues
Known ShellScript Issue
Periphery Documentation