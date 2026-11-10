# Automatic AI-Assisted Cleanup

MiMiNavigator starts the cleanup scanner automatically at launch. It runs as a background-priority task and waits for spare system capacity before each scan step. The scan covers the user's home directory and eligible writable local volumes. System, cloud-storage, backup, and development locations are excluded. Findings are suggestions for review; the feature does not delete files automatically.

## When scanning runs

The scanner proceeds only when all of these conditions are true:

- MiMiNavigator is not the frontmost application.
- The one-minute system load average is below half the number of active processor cores.
- The Mac's thermal state is `nominal`.

It checks again every five seconds while waiting. A completed automatic pass is followed by an approximately three-hour delay before the next pass. The scanner uses a background task priority, so it yields to foreground work. The UI reports that it pauses while MiMiNavigator is active or the system is busy.

## Apple Intelligence requirements and observed setup

AI review applies only to possible leftovers from uninstalled applications. It uses Apple's on-device Foundation Model and can return only **keep** or **review**. It receives the candidate path and category, not the file contents or the user's intent. A **review** result means the item may be worth checking; it is not a claim that deletion is safe. Results are cached against the file's modification date.

In the Cleanup window, AI review applies only to possible application leftovers older than 180 days in the user's Library. It does not review browser caches, cookies, history, or site storage.

AI review requires Apple Intelligence to be enabled and its model to be ready on a supported Mac. If the model is downloading or preparing, the app waits briefly; if it is still unavailable, that candidate is skipped for now. In the current observed setup, Apple Intelligence became available after both the system region was changed to **United States** and the **Siri language** was changed. This is a field observation, not a permanent app requirement: availability, supported languages, and setup steps can change with macOS releases and Apple's service behavior. Check **System Settings → Apple Intelligence & Siri** and **General → Language & Region** when the model is unavailable.

## What the scan can identify

- Likely app leftovers: only items older than 180 days in the configured application-support locations, whose owning application is not installed or running; at most 40 uncached AI reviews are requested per scan pass.
- Stale process artifacts: `.pid` files older than 30 days, only when the referenced process is not running.
- Old installers and temporary files, based on their type and age.
- Exact duplicate content across eligible local volumes; at least one copy should be kept.
- Cache and selected browsing data from known browsers other than the current macOS default, when the browser is closed and the data has been inactive for more than three days. Cookie and site-storage candidates can sign the user out; each candidate remains a manual choice.
- Third-party top-level caches in `~/Library/Caches` when the owning app is closed, the cache has been inactive for more than 90 days, and it is at least 10 MB. System, identity, authentication, password-manager, and known browser cache roots are excluded. Every candidate still requires manual review.
- Known developer caches, including Xcode DerivedData entries and selected package-manager caches, only when inactive for more than 180 days and at least 100 MB. Projects and source trees remain excluded; a cache containing a user-excluded or unreadable path is not offered.
- A deterministic review label marks sensitive browser data and app leftovers, duplicate groups that must retain one copy, and stale or cache candidates that need checking.

The scanner revalidates candidates before offering cleanup actions. Before moving anything to Trash, it checks whether the selected paths are open by a process belonging to the current user; if that check is unavailable or finds an open path, nothing is moved. Review findings and choose explicitly what to move to Trash.

The scan summary reports paths skipped by access or safety rules and paths whose metadata could not be read.

Paths excluded from Cleanup are skipped on later scans and can be restored from the **Excluded** list in the Cleanup window.
