#!/bin/zsh

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
    print -u2 "[ExternalTools] Homebrew is not installed"
    exit 1
fi

uninstall_cask_if_present() {
    local cask="$1"
    if brew list --cask "$cask" >/dev/null 2>&1; then
        print "[ExternalTools] uninstalling cask: $cask"
        brew uninstall --cask "$cask"
    fi
}

link_formula_if_present() {
    local formula="$1"
    if brew list --formula "$formula" >/dev/null 2>&1; then
        print "[ExternalTools] linking formula: $formula"
        brew link "$formula"
    else
        print "[ExternalTools] formula not installed, skipping link: $formula"
    fi
}

print "[ExternalTools] updating Homebrew"
brew update
brew upgrade
uninstall_cask_if_present diffmerge
uninstall_cask_if_present rar
brew install --cask kdiff3
brew install unar p7zip
link_formula_if_present docker
link_formula_if_present pycparser
link_formula_if_present cffi
brew cleanup
brew autoremove
print "[ExternalTools] update complete"
