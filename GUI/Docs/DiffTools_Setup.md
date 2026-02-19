# Diff Tools Setup

MiMiNavigator uses external diff tools depending on what is being compared.

## Files → FileMerge (opendiff)

Bundled with Xcode. No installation needed if Xcode is installed.

```
xcode-select --install
```

## Directories → DiffMerge

Free tool from SourceGear. Install via Homebrew:

```bash
brew install --cask diffmerge
```

### ⚠️ macOS Quarantine Issue

After `brew install --cask diffmerge`, macOS may block DiffMerge with a security warning
("damaged and can't be opened" or "cannot be verified"). This is a known macOS Gatekeeper
quarantine issue with apps installed outside the App Store.

**MiMiNavigator removes quarantine attributes automatically** (`xattr -cr`) on every
DiffMerge launch, so in most cases no manual action is needed.

If you still see a warning, run once manually:

```bash
xattr -cr /Applications/DiffMerge.app
```

If DiffMerge was installed to `~/Applications` instead of `/Applications`:

```bash
xattr -cr ~/Applications/DiffMerge.app
```

### Reinstall if broken

If DiffMerge was previously installed to a wrong location:

```bash
brew reinstall --cask diffmerge
xattr -cr /Applications/DiffMerge.app
```
