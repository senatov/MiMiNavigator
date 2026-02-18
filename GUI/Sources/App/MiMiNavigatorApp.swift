//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import AppKit
import SwiftUI

@main
struct MiMiNavigatorApp: App {
    @State private var appState = AppState()
    @State private var dragDropManager = DragDropManager()
    @State private var contextMenuCoordinator = ContextMenuCoordinator.shared
    @State private var showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    // MARK: -
    init() {
        AppLogger.initialize()
        log.debug("---- Logger initialized ------")
        Task { await BookmarkStore.shared.restoreAll() }
    }

    // MARK: -
    var body: some Scene {
        WindowGroup {
            DuoFilePanelView()
                .environment(appState)
                .environment(dragDropManager)
                .contextMenuDialogs(coordinator: contextMenuCoordinator, appState: appState)
                .onAppear {
                    appDelegate.bind(appState)
                    showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
                }
                .toolbarBackground(Material.thin, for: ToolbarPlacement.windowToolbar)
                .toolbarBackgroundVisibility(Visibility.visible, for: ToolbarPlacement.windowToolbar)
                .onChange(of: scenePhase) {
                    if scenePhase == .background {
                        Task { await BookmarkStore.shared.stopAll() }
                    }
                }
                .toolbar {
                    toolBarItemRefresh()
                    toolBarItemHidden()
                    toolBarOpenWith()
                    toolBarItemSwapPanels()
                    toolBarItemCompare()
                    toolBarItemSearch()
                    toolBarItemBuildInfo()
                }
                // MARK: - File Transfer Confirmation Dialog
                .sheet(isPresented: Binding(
                    get: { dragDropManager.showConfirmationDialog },
                    set: { dragDropManager.showConfirmationDialog = $0 }
                )) {
                    if let operation = dragDropManager.pendingOperation {
                        FileTransferConfirmationDialog(operation: operation) { action in
                            Task {
                                await dragDropManager.executeTransfer(action: action, appState: appState)
                            }
                        }
                    }
                }
                // MARK: - Batch Operation Progress Overlay
                .overlay {
                    if BatchOperationManager.shared.showProgressDialog,
                       let state = BatchOperationManager.shared.currentOperation {
                        ZStack {
                            Color.black.opacity(0.2)
                                .ignoresSafeArea()
                            BatchProgressDialog(
                                state: state,
                                onCancel: {
                                    BatchOperationManager.shared.cancelCurrentOperation()
                                },
                                onDismiss: {
                                    BatchOperationManager.shared.dismissProgressDialog()
                                }
                            )
                        }
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.15), value: BatchOperationManager.shared.showProgressDialog)
                    }
                }
        }
        .defaultSize(width: 1200, height: 700)
        .defaultPosition(.center)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(appState: appState)
        }
    }

    // MARK: - Refresh button (macOS HIG)
    fileprivate func toolBarItemRefresh() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "arrow.triangle.2.circlepath",
                help: "Refresh file lists (⌘R)"
            ) {
                log.debug("Refresh button clicked")
                appState.forceRefreshBothPanels()
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    // MARK: - Hidden files toggle (macOS HIG)
    fileprivate func toolBarItemHidden() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarToggleButton(
                systemImage: "eye.slash",
                activeImage: "eye.fill",
                helpActive: "Hide hidden files (⌘.)",
                helpInactive: "Show hidden files (⌘.)",
                isActive: $showHiddenFiles
            ) {
                log.debug("Hidden toggle clicked")
                showHiddenFiles.toggle()
                UserPreferences.shared.snapshot.showHiddenFiles = showHiddenFiles
                appState.forceRefreshBothPanels()
            }
            .keyboardShortcut(".", modifiers: .command)
        }
    }

    // MARK: - Open With button (macOS HIG)
    fileprivate func toolBarOpenWith() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "arrow.up.forward.app",
                help: "Open file / Get Info for directory (⌘O)"
            ) {
                log.debug("OpenWith button clicked")
                appState.openSelectedItem()
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }

    // MARK: - Find Files button (macOS HIG — search icon)
    fileprivate func toolBarItemSearch() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "magnifyingglass",
                help: "Find Files (⇧⌘F)"
            ) {
                log.debug("Search button clicked")
                let panel = appState.focusedPanel
                let path = panel == .left ? appState.leftPath : appState.rightPath
                let selectedFile = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
                FindFilesCoordinator.shared.toggle(searchPath: path, selectedFile: selectedFile)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }

    // MARK: - Swap panels button — exchange left ↔ right directory
    fileprivate func toolBarItemSwapPanels() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "arrow.left.arrow.right",
                help: "Swap panels — exchange left and right directories"
            ) {
                log.debug("Swap panels button clicked")
                appState.swapPanels()
            }
        }
    }

    // MARK: - Compare button — diff files or directories via FileMerge (opendiff)
    fileprivate func toolBarItemCompare() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "doc.text.magnifyingglass",
                help: "Compare selected items in both panels via FileMerge (opendiff)"
            ) {
                log.debug("Compare button clicked")
                compareItems()
            }
        }
    }

    // MARK: - Build info badge
    fileprivate func toolBarItemBuildInfo() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .status) {
            HStack(spacing: 8) {
                Text("🐈")
                    .font(.caption2)
                    .padding(8)
                    .background(Circle().fill(Color.yellow.opacity(0.1)))
                    .overlay(
                        Circle().strokeBorder(Color.blue.opacity(0.8), lineWidth: 0.04)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("DEV BUILD")
                        .font(.caption2)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    makeDevMark()
                        .font(.caption2)
                        .foregroundStyle(FilePanelStyle.dirNameColor)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 1)
            .background(.yellow.opacity(0.05), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.red, lineWidth: 0.8)
            )
            .help("Current development build version")
        }
    }

    // MARK: - Version string
    private func compareItems() {
        // Resolve what to compare:
        // • Two files selected on one panel (marked) → compare those two files
        // • One file per panel selected → compare left vs right
        // • Otherwise → compare current panel directories
        let focusedPanel = appState.focusedPanel
        let markedOnFocused = appState.markedCustomFiles(for: focusedPanel)
            .filter { !ParentDirectoryEntry.isParentEntry($0) }

        let leftPath: String
        let rightPath: String

        if markedOnFocused.count == 2 {
            // Two items marked on same panel → compare them directly
            leftPath  = markedOnFocused[0].urlValue.path
            rightPath = markedOnFocused[1].urlValue.path
            log.info("[Compare] same-panel: '\(markedOnFocused[0].nameStr)' ↔ '\(markedOnFocused[1].nameStr)'")
        } else {
            let leftFile  = appState.selectedLeftFile
            let rightFile = appState.selectedRightFile
            switch (leftFile, rightFile) {
            case (.some(let l), .some(let r)) where !l.isDirectory && !r.isDirectory:
                leftPath  = l.urlValue.path
                rightPath = r.urlValue.path
                log.info("[Compare] files: '\(l.nameStr)' ↔ '\(r.nameStr)'")
            default:
                leftPath  = appState.leftPath
                rightPath = appState.rightPath
                log.info("[Compare] dirs: '\(leftPath)' ↔ '\(rightPath)'")
            }
        }

        launchDiffTool(left: leftPath, right: rightPath)
    }

    /// Launch best available diff tool.
    /// Priority: DirEqual → FileMerge (opendiff) → kdiff3 → Beyond Compare → App Store offer
    /// Launch DirEqual via Finder Services — the only way to pass real paths without sandbox remapping.
    /// Finder selects both folders, then Services > cmpWithDirEqual opens DirEqual with correct paths.
    private static func launchDirEqualViaFinder(leftPath: String, rightPath: String, frame: NSRect?) {
        // Finder reveal order: right first, left second → DirEqual gets tf1=right, tf2=left
        // So we pass them in reversed order to get left on left, right on right
        let script = """
        tell application "Finder"
            set f1 to (POSIX file \(rightPath.appleScriptQuoted)) as alias
            set f2 to (POSIX file \(leftPath.appleScriptQuoted)) as alias
            reveal {f1, f2}
            activate
        end tell
        delay 0.4
        tell application "System Events"
            tell process "Finder"
                click menu item "cmpWithDirEqual" of menu of menu item "Services" of menu "Finder" of menu bar 1
            end tell
        end tell
        delay 0.3
        tell application "System Events"
            tell process "Finder"
                click button 2 of every window
            end tell
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        if let err {
            log.error("[Compare] Finder Services: \(err["NSAppleScriptErrorMessage"] ?? err)")
            return
        }
        log.info("[Compare] DirEqual launched via Finder Services ✓")
        waitForDirEqualReady(leftPath: leftPath, rightPath: rightPath, frame: frame)
    }

    /// Polls DirEqual every 0.5s until window is ready, then clicks Compare and repositions.
    private static func waitForDirEqualReady(leftPath: String, rightPath: String, frame: NSRect?, attempt: Int = 0) {
        let maxAttempts = 12   // 6 seconds total
        let interval    = 0.5

        // Check if DirEqual window 1 exists and has loaded its path fields
        let checkScript = """
        tell application "System Events"
            if exists process "DirEqual" then
                if (count windows of process "DirEqual") > 0 then
                    return value of text field 2 of group 1 of window 1 of process "DirEqual"
                end if
            end if
            return ""
        end tell
        """
        var checkErr: NSDictionary?
        let result = NSAppleScript(source: checkScript)?.executeAndReturnError(&checkErr)
        let currentTF2 = result?.stringValue ?? ""

        guard !currentTF2.isEmpty else {
            // Window not ready yet — retry
            if attempt < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    waitForDirEqualReady(leftPath: leftPath, rightPath: rightPath, frame: frame, attempt: attempt + 1)
                }
            } else {
                log.warning("[Compare] DirEqual window never appeared after \(maxAttempts) attempts")
            }
            return
        }

        // Window is ready — click Compare and reposition
        let targetFrame = frame ?? NSRect(x: 100, y: 100, width: 1200, height: 800)
        let screenH = NSScreen.main?.frame.height ?? 1080
        let wx = Int(targetFrame.origin.x)
        let wy = Int(screenH - targetFrame.origin.y - targetFrame.height)
        let ww = Int(targetFrame.width)
        let wh = Int(targetFrame.height)

        let fixScript = """
        tell application "DirEqual" to activate
        delay 0.15
        tell application "System Events"
            tell process "DirEqual"
                click button 1 of toolbar 1 of window 1
                delay 0.15
                set position of window 1 to {\(wx), \(wy)}
                set size of window 1 to {\(ww), \(wh)}
            end tell
        end tell
        """
        var fixErr: NSDictionary?
        NSAppleScript(source: fixScript)?.executeAndReturnError(&fixErr)
        if let fixErr {
            log.warning("[Compare] DirEqual setup: \(fixErr["NSAppleScriptErrorMessage"] ?? fixErr)")
        } else {
            log.info("[Compare] DirEqual ready after \(attempt) poll(s) — compare started ✓")
        }
    }

    private func launchDiffTool(left: String, right: String) {
        let leftURL  = URL(fileURLWithPath: left).standardized
        let rightURL = URL(fileURLWithPath: right).standardized
        let ws = NSWorkspace.shared

        // DirEqual — launch via Finder Services to bypass sandbox path remapping
        if ws.urlForApplication(withBundleIdentifier: "com.naarak.DirEqual") != nil {
            let targetFrame = NSApp.mainWindow?.frame
            Self.launchDirEqualViaFinder(leftPath: leftURL.path, rightPath: rightURL.path, frame: targetFrame)
            return
        }

        // Fallback: Process()-based tools (sandbox off in Debug)
        let candidates: [(appPath: String, bin: String)] = [
            ("/Applications/Xcode.app/Contents/Applications/FileMerge.app", "/usr/bin/opendiff"),
            ("/Applications/kdiff3.app",        "/Applications/kdiff3.app/Contents/MacOS/kdiff3"),
            ("/Applications/Beyond Compare.app", "/Applications/Beyond Compare.app/Contents/MacOS/bcomp"),
        ]
        for (appPath, bin) in candidates {
            guard FileManager.default.fileExists(atPath: appPath) else { continue }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: bin)
            task.arguments = [left, right]
            do {
                try task.run()
                log.info("[Compare] launched \(appPath.components(separatedBy: "/").last ?? bin) ✓")
                return
            } catch {
                log.error("[Compare] \(bin): \(error.localizedDescription)")
            }
        }

        // Nothing installed — offer DirEqual from App Store
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "No Diff Tool Found"
            alert.informativeText = "DirEqual is a free App Store tool for comparing folders.\n\nWould you like to open it in the App Store?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open App Store")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                ws.open(URL(string: "macappstore://apps.apple.com/app/id1435575700")!)
            }
        }
        log.info("[Compare] offered DirEqual via App Store")
    }


    private func makeDevMark() -> Text {
        let versionURL = Bundle.main.url(forResource: "curr_version", withExtension: "asc")
        let content: String
        if let url = versionURL, let versionString = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            content = trimmed
        } else {
            let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            if let s = short, let b = build {
                content = "v\(s) (\(b))"
            } else if let s = short {
                content = "v\(s)"
            } else if let b = build {
                content = "build \(b)"
            } else {
                content = "Mimi Navigator — cannot determine version"
                log.error("failed to load version")
            }
        }
        return Text(content)
    }
}
