# Diff Tools Setup.

MiMiNavigator uses external diff tools depending on what is being compared.


## Files → FileMerge (opendiff)

Bundled with Xcode. No installation needed if Xcode is installed.

```
xcode-select --install
```

## Files and Directories → KDiff3

Free comparison tool from KDE. Install via Homebrew:

```zsh
brew install --cask kdiff3
```

Homebrew installs the application as `/Applications/kdiff3.app` and creates the
`kdiff3` command-line launcher. MiMiNavigator passes both selected paths directly
to KDiff3 and supports file and directory comparison.

### Window Positioning

KDiff3 window is positioned **dynamically over the MiMiNavigator main window**
via AppleScript after launch. Window coordinates from the config file are ignored.

## Homebrew Tool Refresh

Run the project maintenance script to remove DiffMerge/RAR, install KDiff3,
`unar` and `p7zip`, refresh packages, and relink configured formulas:

```zsh
zsh Scripts/update_external_tools.zsh
```
