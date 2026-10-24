# MiMiNavigator staged improvements

The staged program covers the entire application. Keep each change small enough to build, inspect, and commit independently. Current development targets macOS 27; v0.9.1.2 is the final macOS 26-compatible release. Check new SwiftUI APIs against the macOS 27 deployment target before adopting them.

## Scope of v0.9.1.2

1. Archive reliability: TAR extraction errors, safe repacking, and recovery of edited contents after a failed repack.
2. Release preparation: four-component decimal versioning, binary MiMiKits verification, and release-sequence validation.
3. Responsiveness: prompt cancellation of blocked directory scans and protection against stale panel updates.
4. GUI: independent, accessible selection and deletion in local filter history.

Complete the signed, notarized, stapled DMG and publish the application release only after these changes are built and verified from the final commit.

## Later stages

The release pipeline now checks the signed app's version and macOS minimum in both `Info.plist` and the executable before creating a DMG. The remaining macOS 27 installation checks below still need validation on a macOS 26 host.
CI now detects Xcode failures piped through `xcbeautify`. Build failures fail the job; tests remain advisory until the UI test suite is validated on the hosted runner.

1. Complete the macOS 27 transition gate: verify the in-app installer against signed candidate metadata, keep legacy clients on v0.9.1.2 in the update feed, enforce the minimum in Homebrew, and move CI to Xcode 27. Deploy the feed before publishing the first macOS 27 release and test rejection on macOS 26. Finder drag-to-install from a DMG cannot run a pre-copy check; decide whether the first 27-only release needs a signed installer package with an OS-version installation check. Existing v0.9.1.2 users on macOS 27 must install the first 27-only release manually because that client does not report its host OS.
2. Record a performance baseline for startup, large folders, scrolling, memory, and remote operations. Use measurements to select the next performance work. Repeat runtime checks on macOS 27.
3. Review project structure, package boundaries, clean-clone builds, compiler settings, and dependency reproducibility. Make one build or dependency change at a time.
4. Review file operations, archive formats, remote navigation, recovery paths, and user-facing error messages with real files and focused tests.
5. Review SwiftUI state ownership, view identity, keyboard and pointer actions, accessibility, window layout, and visual consistency in the running Debug app.
6. Profile concurrency, cancellation, I/O, caches, and large-directory behavior before changing task structure or buffers.
7. Review CI, signing, notarization, update delivery, release notes, and rollback checks before each subsequent release.

## macOS 27 opportunities to assess

- Keep view modes and the fixed menu toggle visible longer with SwiftUI toolbar visibility priorities; expose individual actions in native toolbar overflow. `ToolbarOverflowMenu` is unavailable on macOS in Xcode 27, so assess other platform-specific toolbar APIs before adopting them.
- Try native drag reordering for Favorites and other ordered views; verify stable identity, focus, and accessibility in the running app.
- Review item-bound alerts and confirmation dialogs to reduce duplicated presentation state.
- Profile lazy `@State` initialization and Xcode 27 `ContentBuilder` compilation separately. The compiler benefit comes from Xcode 27, not simply from raising the deployment target.

These are candidates, not shipped features or assumed performance gains. See [Apple's SwiftUI 2027 overview](https://developer.apple.com/swiftui/whats-new/).

Carry every version component after the major number from 0 through 9. For example, `0.9.1.9` is followed by `0.9.2.0`.

## Performance stage 1: local baseline (2026-10-23)

- Host: macOS 27.0.1. The app and private packages retain a macOS 26.0 deployment target; a macOS 26 runtime was unavailable.
- Startup checkpoint: 0.395 seconds in the new Debug build. This is a single warm launch, not a cold-start benchmark.
- Local flat folder: 20,000 empty `.txt` files under `/tmp`. The prior build spent 2.723 seconds in scan/sort. With conditional metadata fallbacks in FileModelKit, the same scan took 1.178 seconds (57% less).
- Full panel refresh in the new build took 2.869 seconds, including 1.249 seconds to publish the result. The before/after panel modes differed, so this total is not a controlled comparison.
- List scrolling by three pages moved the visible window from `file-19999.txt` to `file-19848.txt`. The Debug toolbar reported 48 MB at launch, 266 MB after opening the large folder, and up to 325 MB during the interaction; investigate memory and publication cost separately.
- Remote-operation latency remains unmeasured because no test server or disposable remote directory was available.
- The fix is in the private MiMiKits source. Public binary wrappers and the installed release will receive it when the next release packages are published.
