# Binary MiMiKits distribution

## Status

The distribution pipeline builds private MiMiKits modules as individual static
XCFrameworks. On 2026-09-12 the application built successfully from an isolated
copy with no private Packages directory, using the extracted ZIP artifacts.
The grouped sorting regression test also passed. The public project uses release
`kits-ffba754c7dd76553`, built from MiMiKits commit `7259b0e`. Runtime and UI
behavior remain separate from build verification.

The first artifact set targets Apple Silicon (arm64), macOS 26 or newer for both
the libraries and the application. It is built with Xcode 27 beta
(27A5252f), Swift 6.4. Earlier Xcode versions are not verified. Build future public
artifacts with the oldest supported compiler and test that compiler explicitly.
SwiftyBeaver 2.1.1 and GRDB 7.11.1 remain source dependencies, pinned exactly: they
are not compiled into each MiMiKits archive. Their binary compatibility across
compiler versions is not guaranteed by the private modules' library evolution mode.

## Module ownership

File sorting is implemented in FileModelKit. NetworkKit owns HTTP web-interface
probing and share-enumeration result mapping. ArchiveKit owns format capability
rules for compression level selection and password support. The application keeps
UI presentation and interaction policies.

## Maintainer build

On the maintainer's Mac, with the private `Packages` checkout present:

```zsh
zsh Scripts/build_binary_packages.zsh
zsh Scripts/verify_binary_packages.zsh
```

The builder stages sources under ignored `build/binary-packages/work`, enables
library evolution for private modules, and packages only each module's own object
files plus its public Swift interface. It excludes private/package interfaces,
source files, debug symbol bundles, and third-party object files. Public API names
remain visible; binaries do not prevent reverse engineering.

Artifacts are in `build/binary-packages/artifacts`. `build-info.json` records the
compiler, source revision, source-content digest, and archive-set identifier.
The archive digest determines an immutable `kits-<identifier>` release tag.
Changing an archive requires a new identifier and regenerated SPM checksums.
The source revision may have local changes; the source digest records the staged
Swift source content actually built.

The verification script copies tracked application files into an isolated folder,
omits `Packages` and `.gitmodules`, extracts the distributable ZIP archives, generates local binary package wrappers, and
builds using a separate DerivedData directory. It keeps the regular checkout and
running application intact. Run-time and UI testing are additional checks.

## Public delivery

The public wrappers live in `BinaryPackages/<module>/Package.swift`. Each has an
explicit dependency target so SwiftPM links its binary with the required modules
and open-source products without duplicating their implementation. Archives are
hosted as release assets of MiMiNavigator; no additional public repository is needed.

To publish a replacement artifact set:

1. Commit the MiMiKits source changes and complete the source-free local
   verification build.
2. Preview generated public manifests with `python3 Scripts/BinaryPackages/configure.py --stage`.
   Publish only `*.xcframework.zip` and `build-info.json`, plus the agreed license
   documents. Never upload the `work` directory.
3. Run `python3 Scripts/BinaryPackages/configure.py` to generate URL/checksum
   manifests and switch the project to `BinaryPackages`.
4. Test a clean clone with fresh dependency caches and anonymous
   access to every archive, then update the README build instructions.

## Local source development

Maintainers can clone the private MiMiKits repository into `Packages` with their
authorized GitHub account and run:

```zsh
zsh Scripts/use_source_packages.zsh
```

This is a local project-file override; do not commit it. To return to the checked-in
binary configuration without regenerating artifacts, restore only the project
file after preserving any unrelated project edits. A regular contributor needs
neither this command nor access to the private submodule.
