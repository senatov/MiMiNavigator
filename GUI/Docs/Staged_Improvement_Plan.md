# MiMiNavigator staged improvements

The staged program covers the entire application. Keep each change small enough to build, inspect, and commit independently. Preserve the macOS 26 deployment target and check new SwiftUI APIs against that target before adopting them.

## Scope of v0.9.1.2

1. Archive reliability: TAR extraction errors, safe repacking, and recovery of edited contents after a failed repack.
2. Release preparation: four-component decimal versioning, binary MiMiKits verification, and release-sequence validation.
3. Responsiveness: prompt cancellation of blocked directory scans and protection against stale panel updates.
4. GUI: independent, accessible selection and deletion in local filter history.

Complete the signed, notarized, stapled DMG and publish the application release only after these changes are built and verified from the final commit.

## Later stages

1. Record a macOS 26 baseline for startup, large folders, scrolling, memory, and remote operations. Use measurements to select the next performance work.
2. Review project structure, package boundaries, clean-clone builds, compiler settings, and dependency reproducibility. Make one build or dependency change at a time.
3. Review file operations, archive formats, remote navigation, recovery paths, and user-facing error messages with real files and focused tests.
4. Review SwiftUI state ownership, view identity, keyboard and pointer actions, accessibility, window layout, and visual consistency in the running Debug app.
5. Profile concurrency, cancellation, I/O, caches, and large-directory behavior before changing task structure or buffers.
6. Review CI, signing, notarization, update delivery, release notes, and rollback checks before each subsequent release.

Carry every version component after the major number from 0 through 9. For example, `0.9.1.9` is followed by `0.9.2.0`.
