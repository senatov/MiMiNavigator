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

## Files and Directories → IntelliJ IDEA

IntelliJ IDEA can be used as an optional external file and directory diff
viewer. JetBrains documents the command-line diff syntax as:

```zsh
idea diff <path1> <path2> [<path3>]
```

For folder comparison, JetBrains documents the same form:

```zsh
<path to IntelliJ IDEA executable file> diff <path_1> <path_2>
```

MiMiNavigator uses this mode only as an external viewer. It does not bundle
IntelliJ IDEA and does not require it for normal file-manager operation.

### Installation

Recommended installation methods:

- JetBrains Toolbox App: install IntelliJ IDEA and let Toolbox manage updates.
- Standalone macOS disk image: download IntelliJ IDEA from JetBrains, mount the
  DMG, and drag the app into `/Applications`.
- Homebrew cask, when preferred for local development machines:

```zsh
brew install --cask intellij-idea-ce
```

MiMiNavigator detects these common locations:

- `/Applications/IntelliJ IDEA CE.app`
- `/Applications/IntelliJ IDEA.app`
- `/Applications/IntelliJ IDEA Ultimate.app`
- `~/Applications/IntelliJ IDEA CE.app`
- `~/Applications/IntelliJ IDEA.app`

It also accepts existing command-line launchers at `/usr/local/bin/idea`,
`/opt/homebrew/bin/idea`, or `~/bin/idea`.

### License and Cost

JetBrains changed IntelliJ IDEA distribution starting with IntelliJ IDEA 2025.3:
the product is unified, the former Community Edition functionality remains free
for non-commercial and commercial use, and the extended Ultimate tooling is
available through a paid subscription after the trial. For MiMiNavigator diff
integration, the free core functionality is enough.

### Launch Behavior

MiMiNavigator launches the built-in IntelliJ preset through macOS `open`:

```zsh
open -n /Applications/IntelliJ\ IDEA\ CE.app --args diff <left> <right>
```

The `-n` flag asks macOS to create a fresh IntelliJ instance for the compare
session. This avoids routing a new compare request into an old JetBrains process
that can remain alive after the diff window is closed.

Official JetBrains references:

- [Compare files from the command line](https://www.jetbrains.com/help/idea/command-line-differences-viewer.html)
- [Diff Viewer for folders](https://www.jetbrains.com/help/idea/differences-viewer-for-folders.html)
- [Install IntelliJ IDEA](https://www.jetbrains.com/help/idea/installation-guide.html)
- [Unified IntelliJ IDEA announcement](https://blog.jetbrains.com/idea/2025/12/intellij-idea-unified-release/)

## Homebrew Tool Refresh

Run the project maintenance script to remove DiffMerge/RAR, install KDiff3,
`unar` and `p7zip`, refresh packages, and relink configured formulas:

```zsh
zsh Scripts/update_external_tools.zsh
```
