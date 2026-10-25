# MiMiNavigator staged improvements

The staged program covers the entire application. Keep each change small enough to build, inspect, and commit independently. Current development targets macOS 27; v0.9.1.2 is the final macOS 26-compatible release. Check new SwiftUI APIs against the macOS 27 deployment target before adopting them.

## Completed in v0.9.1.2

1. Archive reliability: TAR extraction errors, safe repacking, and recovery of edited contents after a failed repack.
2. Release preparation: four-component decimal versioning, binary MiMiKits verification, and release-sequence validation.
3. Responsiveness: prompt cancellation of blocked directory scans and protection against stale panel updates.
4. GUI: independent, accessible selection and deletion in local filter history.

The signed, notarized, stapled v0.9.1.2 DMG was published after these changes.

## Current release: v0.9.1.3

The first macOS 27-only release is published. Its app and executable minimum-version checks, in-app replacement guard, macOS 27/Xcode 27 CI configuration, and native toolbar overflow are in place. The README documents the OS-aware update feed and Homebrew minimum-version check. Local titlebar changes after the release keep the notice button above the panel divider, put resource graphs to its left, group actions on a compact native surface, and show the documented release date without covering it. These changes are not part of v0.9.1.3.

## Later stages

The release pipeline checks the signed app's version and macOS minimum in both `Info.plist` and the executable before creating a DMG. Build failures behind `xcbeautify` fail CI; tests remain advisory until the UI test suite is validated on the hosted runner.

1. Validate the macOS 27 transition on a macOS 26 host: check the OS-aware feed, Homebrew rejection, and the in-app installer against the signed v0.9.1.3 candidate. Finder drag-to-install from a DMG cannot run a pre-copy check; decide whether a future release needs a signed installer package with an OS-version installation check. Existing v0.9.1.2 users on macOS 27 must install v0.9.1.3 manually because that client does not report its host OS.
2. Record a performance baseline for startup, large folders, scrolling, memory, and remote operations. Use measurements to select the next performance work. Repeat runtime checks on macOS 27.
3. Review project structure, package boundaries, clean-clone builds, compiler settings, and dependency reproducibility. Make one build or dependency change at a time.
4. Review file operations, archive formats, remote navigation, recovery paths, and user-facing error messages with real files and focused tests.
5. Review SwiftUI state ownership, view identity, keyboard and pointer actions, accessibility, window layout, and visual consistency in the running Debug app.
6. Profile concurrency, cancellation, I/O, caches, and large-directory behavior before changing task structure or buffers.
7. Review CI, signing, notarization, update delivery, release notes, and rollback checks before each subsequent release.

## macOS 27 opportunities to assess

- Recheck the compact native toolbar group, view-mode visibility priorities, and individual action labels at narrow Commander window widths. `ToolbarOverflowMenu` is unavailable on macOS in Xcode 27, so assess other platform-specific toolbar APIs before adopting them.
- Try native drag reordering for Favorites and other ordered views; verify stable identity, focus, and accessibility in the running app.
- Review item-bound alerts and confirmation dialogs to reduce duplicated presentation state.
- Profile lazy `@State` initialization and Xcode 27 `ContentBuilder` compilation separately. The compiler benefit comes from Xcode 27, not simply from raising the deployment target.

These are candidates, not shipped features or assumed performance gains. See [Apple's SwiftUI 2027 overview](https://developer.apple.com/swiftui/whats-new/).

Carry every version component after the major number from 0 through 9. For example, `0.9.1.9` is followed by `0.9.2.0`.

## Performance stage 1: local baseline (2026-10-23)

- Host: macOS 27.0.1. At the time of this measurement, the app and private packages retained a macOS 26.0 deployment target; a macOS 26 runtime was unavailable. v0.9.1.3 later raised the target to macOS 27.
- Startup checkpoint: 0.395 seconds in the new Debug build. This is a single warm launch, not a cold-start benchmark.
- Local flat folder: 20,000 empty `.txt` files under `/tmp`. The prior build spent 2.723 seconds in scan/sort. With conditional metadata fallbacks in FileModelKit, the same scan took 1.178 seconds (57% less).
- Full panel refresh in the new build took 2.869 seconds, including 1.249 seconds to publish the result. The before/after panel modes differed, so this total is not a controlled comparison.
- List scrolling by three pages moved the visible window from `file-19999.txt` to `file-19848.txt`. The Debug toolbar reported 48 MB at launch, 266 MB after opening the large folder, and up to 325 MB during the interaction; investigate memory and publication cost separately.
- Remote-operation latency remains unmeasured because no test server or disposable remote directory was available.
- The fix was in private MiMiKits source at the time of this measurement; v0.9.1.3 subsequently published the updated packages.

## Performance stage 2: bounded column-width sampling (2026-10-24)

- Large-directory autofit still measures visible rows first and keeps the same evenly spaced background sample of at most 300 entries.
- The background sampler now accesses only those selected entries instead of traversing the full directory array. It also clamps the excluded window to valid array bounds.
- The Debug build and four focused `LargeDirectoryPolicyTests` passed on macOS 27.0.1. Runtime memory and scrolling measurements remain a separate stage.

## Performance stage 3: flat-directory publication (2026-10-24)

- Used the requested VS Code extension `webview/assets` directory as a read-only fixture: 19,367 files and no immediate subfolders.
- Skip parent-entry array mutation when the scan has no `..` entry, and skip the old-file size lookup when the incoming scan has no directories.
- The Debug app displayed all 19,367 rows. An unchanged forced refresh skipped republishing the panel. One initial scan took 1.630 seconds for scan/sort and 0.411 seconds for publication; this single run does not establish an end-to-end speedup.
- The remaining full-list content hash and table snapshot rebuild were measured in stages 5–8 below.

## Performance stage 4: sorted table snapshot (2026-10-24)

- Removed the unused sorted-file array from table view state. The snapshot now keeps only rows and the selection index.
- When no synthetic parent entry is present, the sorted array becomes the row array directly; filtering still removes `..` when present.
- The Debug build and focused snapshot test passed on macOS 27.0.1. In the running Debug app, the requested 19,367-file directory displayed all items, and jump-to-bottom and jump-to-top navigation worked.
- This removes one array allocation on the flat-folder path; total memory savings were not measured.

## Performance stage 5: scan publication hashing (2026-10-24)

- On the requested 19,367-file `webview/assets` fixture, full content hashing took about 40 ms on the main actor in two forced-refresh samples. Building the sorted table snapshot took 135–161 ms, already in a detached task.
- Large-directory hashing now runs in a detached task. A per-panel publication generation and expected-path check discard stale results after overlapping refreshes or navigation; smaller folders keep the synchronous path.
- The Debug build displayed all 19,367 files, and an unchanged forced refresh still skipped duplicate publication. The first off-main hash measurements took 43–52 ms including task scheduling; these samples do not establish an end-to-end speedup.

## Performance stage 6: reuse sorted scan order (2026-10-24)

- The scanner already sorts local scan results. For a table with at least 2,000 rows, the snapshot now checks adjacent items against its active comparator and reuses the input order when it is valid. A changed order still takes the normal sort path.
- On the requested 19,367-file fixture, the Debug log confirmed `reusedInput=true` for the date-sorted table after publication. Snapshot construction took 123–135 ms in two runs; the previous 135–161 ms samples overlap, so an overall speedup is not established. Reusing the order avoids one full-size sort array allocation.
- A focused test covers the large sorted path and re-sorting after a direction change. The verification scan remains linear and can still be expensive when many adjacent values require localized name comparisons.

## Performance stage 7: single-pass row metadata (2026-10-25)

- Combined synthetic-parent detection with selection indexing and directory/permission metadata collection. Flat directories reuse the sorted rows without a separate parent-entry scan; directories containing `..` still filter it and keep correct row offsets.
- The focused sorted-snapshot tests passed on macOS 27, including parent exclusion and a 2,000-row sort-direction change. The 19,367-file fixture was not remeasured in this stage, so the total runtime effect remains unquantified.

## Performance stage 8: off-main publication preparation (2026-10-25)

- Measured the requested read-only `webview/assets` fixture in the running Debug app: 19,367 files, 1.562 seconds for the scan, 1.252 seconds in publication, and 154 ms for the table snapshot. The pre-change publication included a full-list parent-entry check on the main actor; the content hash alone took 42 ms off-main.
- For lists of at least 2,000 entries, parent-entry normalization and the content hash now run together in one detached task. Smaller lists retain the direct path. The existing generation and path guards still discard stale preparation results. Normalization now recognizes the actual `..` marker used by `ParentDirectoryEntry.make`, including duplicate entries.
- After rebuilding and relaunching, the same fixture displayed 19,367 items, and jump-to-bottom, jump-to-top, and unchanged refresh worked. Preparation took 43–49 ms off-main. A focused test confirmed flat input and duplicate `..` normalization. One launch measured 1.619 seconds for scan/sort and 0.384 seconds for publication; the before run navigated through Favorites while the after run restored an existing tab, so this is not a controlled end-to-end speedup claim.
- Debug memory footprint rose from 123 MB before navigation to 286 MB after loading the folder; the later relaunched Debug process reached 407 MB after refreshing and scrolling. Memory growth remains a separate profiling target. Remote-operation latency remains unmeasured.

## Performance stage 9: large-directory memory observation (2026-10-25)

- Revisited the same read-only `webview/assets` fixture with 19,367 files in List mode in a warm Debug process. The last checkpoint before navigation reported a 123 MB footprint; the periodic checkpoint after loading reported 296 MB. The scan took 1.607 seconds, publication 0.364 seconds, and the sorted table snapshot 0.051 seconds. The baseline checkpoint preceded navigation by about 53 seconds, so it is not an immediate before sample.
- Three pages of list scrolling raised the toolbar footprint to 366 MB. `vmmap` showed approximately 187 MB allocated in malloc zones after loading and 232 MB after scrolling; AttributeGraph allocations rose from about 29 MB to 40 MB. These are single-process observations, not a controlled before/after comparison.
- After navigating back to the small parent folder, the toolbar footprint fell to 225 MB and malloc-zone allocated bytes fell to about 126 MB. The process RSS remained high because freed allocations and mapped pages need not immediately leave the resident set. This run does not establish a leak or the owner of the retained footprint.
- Next repeat a controlled open/scroll/leave cycle from a fresh List-mode process and capture an Instruments Allocations trace if footprint grows across cycles. Keep the large-directory content cache limit (5,000 files per entry) in mind: this 19,367-file listing is not stored by `DirectoryContentCache`.
