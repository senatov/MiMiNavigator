# Runtime diagnostics

MiMiNavigator writes the current process log to `/private/tmp/MiMiNavigator.log`. The app also keeps a rotating log under its Application Support directory. Logs contain local file paths and remote server names; review them before sharing.

## Responsiveness

`[Responsiveness] main-queue-delayed` means the background probe could not receive a main-queue reply on its next three-second tick. It records the measured delay, process ID, thread count, memory footprint, active operations, and the four most recent completed operations. `main-queue-recovered` records the total delay. `monitor-gap` means the background probe itself stopped running for more than ten seconds, as can happen when the Mac sleeps; its pending delay measurement is reset.

The activity snapshot reports the total active count and lists at most eight oldest active and four recent completed operations. It currently tracks directory scans, recursive directory sizing, and column Autofit. Empty `active` does not prove that the app was idle: AppKit, SwiftUI, and other work are outside this tracker. To identify the blocking stack, capture a process sample while a delay is happening, for example with Activity Monitor's **Sample Process** command. Match its time and PID to the log.

## Directory sizes

`[DirectorySizeService] fullRecursive` lines include the scan mode, path, visited entries, elapsed time, and outcome. Standard automatic scans are limited to 200,000 entries or eight seconds. A budget result is cached for the current directory context, and the row leaves size unavailable without marking the directory restricted or launching a larger fallback scan. Cache invalidation after file changes or volume mounts allows a later attempt. Unreadable and cancelled scans have separate outcomes; fallback behavior for paths that cannot be read directly remains available.

## Reading the log

Start with warning and error lines, then inspect surrounding scan, size, and Autofit events. Compare `footprintMB` and `[Memory]` checkpoints across several minutes before treating an increase as a leak. View initialization is not a reliable measure of SwiftUI rendering cost, so constructor logging is intentionally omitted from the breadcrumb toolbar.
