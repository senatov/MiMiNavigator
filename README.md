
<div style="text-align: center;">
  <img
    src="GUI/Assets.xcassets/AppIcon.appiconset/120.png"
    alt="Preview FrontEnd"
    title="Logo"
    style="max-width: 100%; height: auto; border: 2px; border-radius: 4px;" />
</div>


> 💡 ***If you are only interested in the source code implementation of this app, you can explore it directly here:***
> <span style="color:#8B0000; font-weight:bold;">👉 [MiMiNavigator / GUI / Sources](https://github.com/senatov/MiMiNavigator/tree/master/GUI/Sources)</span>


---
### MiMiNavigator - MacOS File manager with two panels
## (NOT READY YET, still under Development)



[![Swift Version](https://img.shields.io/badge/Swift-6.2-blue.svg)](https://swift.org)
[![Xcode Version](https://img.shields.io/badge/Xcode-26-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Framework](https://img.shields.io/badge/Framework-SwiftUI-blueviolet.svg)](https://developer.apple.com/xcode/swiftui/)
[![Mac Studio](https://img.shields.io/badge/Device-Mac_Studio_M2Max-orange.svg)](https://www.apple.com/mac-studio/)
[![Memory](https://img.shields.io/badge/RAM-32_GB-brightgreen.svg)]()
[![Encryption](https://img.shields.io/badge/Encryption-Enabled-green.svg)]()
[![Programming](https://img.shields.io/badge/Type-Free_Programming-lightblue.svg)]()
[![Shareware](https://img.shields.io/badge/License-Freeware-yellow.svg)]()


---
##     Overview
MiMiNavigator is a macOS file manager built with Swift and SwiftUI.
The repository is organized around an Xcode project with sources under `MiMiNavigator/` and basic tests in `MiMiNavigatorTests` and `MiMiNavigatorUITests`.

<div style="text-align: center;" >
  <img
    src="GUI/Docs/Screenshot 2025-11-07 at 21.52.17.png"
    alt="Preview FrontEnd"
    title="Preview"
    style="max-width: 100%; height: auto; border: 2px solid #133347ff; border-radius: 4px;" />
</div>



---
### General structure

Key directories inside `MiMiNavigator/`:

- **App** entry point and logging setup. The application reads a `.version` file, sets up a shared model container, and displays a main split view UI with a log viewer button. The code uses SwiftyBeaver for logging.

- **States** observable classes and actors that hold runtime state. `AppState` tracks the current directories and selected files, while `DualDirectoryScanner` scans both panels using timers and async updates.

- **Models** data structures such as `CustomFile`, an entity representing files or directories, and `FileSingleton`, an actor maintaining left/right file lists for SwiftUI updates.

- **Views** SwiftUI views for file panels, the top menu bar, and toolbar. `TotalCommanderResizableView` composes the main UI with a draggable divider and toolbar buttons for actions like view, edit, copy, and delete.

- **BreadCrumbNav** editable path controls and breadcrumb navigation.

- **Favorite** scans frequently used directories and mounted volumes to show a favorites tree.

- **Menus** menu item models and top menu rendering.

Other resources include asset catalogs, entitlements files, and a `refreshVersionFile.zsh` script that updates the `Gui/curr_version.asc` string.


---
### Important aspects

- **Concurrency** Directory scanning and file updates are handled by actors (`DualDirectoryScanner`, `FileSingleton`) and async tasks to keep the UI responsive.

- **User preferences** Window sizes, panel widths, and other state are stored using `UserPreferences`(UserDefaults wrappers).

- **Logging** `LogMan` sets up **SwiftyBeaver** console and file logging with custom icons for log levels.

- **Customization** Many UI components (menu buttons, path control, tooltip) are implemented as reusable **SwiftUI** views.

---
### Getting started

1. Clone the repository and open `MiMiNavigator.xcodeproj` in Xcode.

2. Build and run. The README outlines basic installation steps and features such as dual panel navigation and periodic directory scanning.

3. The main entry point is `MiMiNavigatorApp` which initializes logging and sets up the main view hierarchy. Explore `AppState` and `DualDirectoryScanner` to understand how directory changes propagate to the UI.

---
### Learning pointers

- **SwiftUI layout and modifiers** Many views use custom modifiers and gestures (e.g., `onHover`, drag gestures for the divider).

- **Actors and concurrency** `DualDirectoryScanner` demonstrates using timers inside an actor for periodic work.

- **AppKit interop** Some components rely on `NSWorkspace`, `NSAlert`, and other AppKit APIs for macOS 16.4 specific functionality.

- **Persistent data** The app uses SwiftData `ModelContainer` for future persistence, though currently the `Item`model is minimal.

This project is still under active development ( NOT READY YET  per the README) but provides a clear example of a SwiftUI macOS application with multithreading, logging, and modular UI components.

---
## Current Stage

-  Support for macOS 26 with Swift 6.2 beta5.
-  Periodic directory scanning and updating, using dynamic collections for real-time content refresh.
-  Modular and reusable components for top navigation.
-  Integrated file management actions including copy, rename, and delete.
-  Full Total Commander submenu structure recreated.
-  Dynamic output naming in shell utilities.
-  Dual-panel interface for managing files and directories.
-  Automatic UI updates when directory contents change.



---
## Requirements

- macOS 26 or later
- Swift 6.2
- Xcode 26.1 beta


---
##  Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/username/MiMiNavigator.git
    cd MiMiNavigator
    ```
2. Open the project in Xcode:
    ```sh
    open MiMiNavigator.xcodeproj
    ```
3. Build and Run through Xcode or with the command:
    ```sh
    xcodebuild -scheme MiMiNavigator -configuration Debug CODE_SIGNING_ALLOWED=YES
    ```
4. Check sources
    ```sh
    * periphery scan --project MiMiNavigator.xcodeproj --schemes MiMiNavigator *
    ```


---
 ## Usage

1. Launching: Open the application and set directories for dual-panel mode.
2. File Operations:
    - Copy: Use the `Copy` option in the context menu for quick file duplication.
    - Rename: Select `Rename` and specify the new name.
    - Delete: Use `Delete` to move the file to the trash.
3. Automatic Updates: The application will periodically scan the specified directories and refresh content in real time.



---
## Authors

- Iakov Senatov:  [![LinkedIn](https://img.shields.io/badge/LinkedIn-Profile-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/iakov-senatov-07060765)

| Step                | Description                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| Installation        | Clone the repository, navigate to the project directory, and install dependencies as required. |
| Running the Project | Use the command `swift run` to launch the project.                                             |
| Usage               | Access features like configuration, file management, network, and tools from the main menu.    |





---
## FAQ

| Question                             | Answer                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------- |
| How to configure settings?           | Navigate to Configuration to access display, layout, and color settings.  |
| How to compare directories?          | Use the Files menu to compare and sync directories.                       |
| Can I rename multiple files at once? | Yes, use the Multi-Rename Tool available under Tools.                     |
| Is FTP supported?                    | Yes, FTP connection tools are available under the Network menu.           |
| Clean the Project from artefacts     | periphery scan --config .periphery.yml                                    |



---
## Recent Changes
```sh

* 085a426 - Senatov  (HEAD -> Err-Fix-Down-Panel) command shell call (56 seconds ago, 2025-11-12 22:37:23 +0100)
* 8fcc8ff - Senatov  no more View just helper:  ConsoleCurrPath.open (2 hours ago, 2025-11-12 20:09:07 +0100)
* 8da07ff - Senatov  (origin/master, origin/HEAD, master) NOT TESTED fix(ui): bottom toolbar visibility & layout restored, added LiquidGlass contrast + vibrant icons (24 hours ago, 2025-11-11 22:23:41 +0100)
* 2469d80 - Senatov  ensure it never covers the bottom toolbar visually (28 hours ago, 2025-11-11 18:49:08 +0100)
* 3c33a70 - Senatov  cleaned prj from obsoletes (33 hours ago, 2025-11-11 14:01:29 +0100)
* f34489a - Senatov  fix3-6: drop some shit, Figma Styles (5 days ago, 2025-11-07 21:49:58 +0100)
* 1ea884f - Senatov  fix 2-3: Figma Style/macOS 26.1 (5 days ago, 2025-11-07 21:45:27 +0100)
* eefbd04 - Senatov  fix1 Figma Style macOS 26.1 (5 days ago, 2025-11-07 20:39:06 +0100)
* 4c99e82 - Senatov  refactor, UI-test -OK (5 days ago, 2025-11-07 15:56:43 +0100)
* 9a513c1 - Senatov  jump to 50% on Double Click on Divider (6 days ago, 2025-11-06 20:36:00 +0100)
* 094c19e - Senatov  err on panels divider = 54% on Start (6 days ago, 2025-11-06 19:49:51 +0100)
* b363863 - Senatov  clean & refactoring. Tested. ok (10 days ago, 2025-11-02 19:33:56 +0100)
* 628ca77 - Senatov  popup percentage booble-tooltip (12 days ago, 2025-11-01 03:19:08 +0100)
* 4c50c1c - Senatov  popup percentage booble-tooltip (12 days ago, 2025-11-01 03:19:08 +0100)
* a7923e8 - Senatov  щл (10 days ago, 2025-11-02 15:17:22 +0100)
* 922e02a - Senatov  (tag: from_01.11.2025) Stage 1. OK. (12 days ago, 2025-10-31 20:55:41 +0100)
* 4aa1520 - Senatov  ok. tested (12 days ago, 2025-10-31 20:43:14 +0100)
* 895c93c - Senatov  trottling DONE. tested ok (12 days ago, 2025-10-31 14:53:51 +0100)
*   c89deba - Senatov  merging (12 days ago, 2025-10-31 14:44:18 +0100)
|\  
| * 6e08dd8 - Senatov  temp: pre-rollback (12 days ago, 2025-10-31 14:14:47 +0100)
| * 441c2a3 - Senatov  rename TotalCommanderResizableView  to DuoFilePanelView (12 days ago, 2025-10-31 14:09:31 +0100)
| * 0a01186 - Senatov  fix4 (13 days ago, 2025-10-31 01:22:16 +0100)
| * a74d8f6 - Senatov  pre-build (13 days ago, 2025-10-30 20:10:49 +0100)
* | 1f383e1 - Senatov  temp: pre-rollback (13 days ago, 2025-10-30 19:46:10 +0100)
* | ca8bd18 - Senatov  (tag: tabbing-ok) rename on DuoFilePanelView (2 weeks ago, 2025-10-28 21:49:50 +0100)
* | 5885b9a - Senatov  merge (2 weeks ago, 2025-10-28 21:39:27 +0100)
|/  
* 2f3bf45 - Senatov  panel divider fixed. Test ok (2 weeks ago, 2025-10-28 21:05:10 +0100)
* 21bea20 - Senatov  cosmetic (2 weeks ago, 2025-10-28 16:18:07 +0100)
* 84637c5 - Senatov  fixed panel focus - just formatted (2 weeks ago, 2025-10-28 16:07:48 +0100)
* 0b3f040 - Senatov  focus repaired (2 weeks ago, 2025-10-28 16:06:55 +0100)
* c7befc0 - Senatov  next fix (2 weeks ago, 2025-10-28 15:50:39 +0100)
* 644c56a - Senatov  nex fix (2 weeks ago, 2025-10-28 15:24:44 +0100)
* d47eef1 - Senatov  log fix (2 weeks ago, 2025-10-28 11:47:03 +0100)
* 9e9d0e2 - Senatov  wrong jump on Top of List - fixed (2 weeks ago, 2025-10-26 21:31:21 +0100)
* 5bf0ea5 - Senatov  R-Mouse mnu ,fix focus jump on down selection (2 weeks ago, 2025-10-26 19:15:22 +0100)
* 602b0a9 - Senatov  logs, fix styles, macOS 26.1 liquid glass style (3 weeks ago, 2025-10-25 23:53:40 +0200)
* 8df17a9 - Senatov  scweinkram (3 weeks ago, 2025-10-25 23:11:33 +0200)
* a81a9b2 - Senatov  The left and right sides get mixed up when I click on “Navigation between favorites” — apparently it’s caused by favoritePopover() (3 weeks ago, 2025-10-25 19:20:38 +0200)
* c5e6d9f - Senatov  security bookmarks (3 weeks ago, 2025-10-25 18:18:07 +0200)
* ec7edfe - Senatov  UX Design fix (3 weeks ago, 2025-10-25 17:51:41 +0200)
* d939f0f - Senatov  Excellent. Everything works! Navigation with mouse and Tab (3 weeks ago, 2025-10-25 15:07:54 +0200)
* 169da9f - Senatov  save between fixies (works wrong) (3 weeks ago, 2025-10-24 17:08:55 +0200)
* b8b8513 - Senatov  history ok. Но выделение строки и низ по-прежнему дерьмово провисает. (3 weeks ago, 2025-10-23 23:01:17 +0200)
* 8491639 - Senatov  FileTableView   - err (3 weeks ago, 2025-10-23 20:03:08 +0200)
* 2324bf2 - Senatov  error (3 weeks ago, 2025-10-23 19:04:14 +0200)
* c6f9938 - Senatov  compillation error (3 weeks ago, 2025-10-23 18:41:21 +0200)
* f2c227e - Senatov  build info (3 weeks ago, 2025-10-23 15:38:37 +0200)
*   b9ac683 - Senatov  Merge branch 'check_popups_fix' (3 weeks ago, 2025-10-23 15:35:08 +0200)
|\  
| * 1fdce74 - Senatov  ok. Not tested yet! (3 weeks ago, 2025-10-23 15:29:09 +0200)
| * 0492725 - Senatov  Fix popup on prozess. Selection focuser panel side in logs with "<< >>" (3 weeks ago, 2025-10-23 14:25:40 +0200)
| * a087fa6 - Senatov  def. fixed before test (3 weeks ago, 2025-10-23 05:11:43 +0200)
| * 9ba4e47 - Senatov  wrong (3 weeks ago, 2025-10-23 04:52:03 +0200)
| * dce701f - Senatov  just try fix popup. Hasnt successfull. (3 weeks ago, 2025-10-21 21:20:07 +0200)
* | 26b1be3 - Senatov  wrong (3 weeks ago, 2025-10-23 04:18:43 +0200)
* | 46e4a71 - Senatov  colors, Styles - ok. Working on popup panel - not ok yet (3 weeks ago, 2025-10-22 14:24:08 +0200)
* | a19d8bf - Senatov  fix deive popup. in process (3 weeks ago, 2025-10-22 00:35:38 +0200)
* | 55a6778 - Senatov  something 2 Weeks old, don't know (3 weeks ago, 2025-10-21 17:05:02 +0200)
|/  
* e5671b8 - Senatov  UIViewRepresentable was need only f. SwiftUI 5 (5 weeks ago, 2025-10-09 18:34:33 +0200)
* 577fd9f - Senatov  opening ok. Ugly popup fav. self w. ugly closed functional err. (5 weeks ago, 2025-10-09 15:18:52 +0200)


```



---
 ##  Related Links

- [(NOT READY YET, still under Development)](#not-ready-yet-still-under-development)
- [Overview](#overview)
  - [General structure](#general-structure)
  - [Important aspects](#important-aspects)
  - [Getting started](#getting-started)
  - [Learning pointers](#learning-pointers)
- [Current Stage](#current-stage)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Authors](#authors)
- [FAQ](#faq)
- [Recent Changes](#recent-changes)
- [Related Links](#related-links)
