// MiMiNavigatorApp.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: App entry point. Wires toolbar, panels, drag-drop, network mount callback.
//   Network Neighborhood opens as standalone NSPanel via NetworkNeighborhoodCoordinator.
//   SMB mount: silent via /sbin/mount_smbfs, no Finder fallback.

import AppKit
import NetworkKit
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
        Task { await RemoteConnectionManager.shared.connectOnStartIfNeeded() }
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
                    AppStateProvider.shared = appState
                    showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
                    // Wire connect callback for ConnectToServer panel
                    ConnectToServerCoordinator.shared.onDisconnect = {
                        Task { @MainActor in
                            // Restore whichever panel(s) are showing remote content
                            if AppState.isRemotePath(appState.leftPath) {
                                await appState.restoreLocalPath(for: .left)
                            }
                            if AppState.isRemotePath(appState.rightPath) {
                                await appState.restoreLocalPath(for: .right)
                            }
                        }
                    }
                    ConnectToServerCoordinator.shared.onConnect = { url, password in
                        Task { @MainActor in
                            let side = appState.focusedPanel
                            // Build authenticated URL if password provided
                            var connectURL = url
                            if !password.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                                // Ensure both user and password are in URL for mount_smbfs
                                if components.user == nil || components.user?.isEmpty == true {
                                    components.user = "guest"
                                }
                                components.password = password
                                connectURL = components.url ?? url
                            }
                            let scheme = url.scheme ?? ""
                            log.info("[ConnectToServer] connecting \(scheme)://\(url.host ?? "")")
                            if scheme == "smb" || scheme == "afp" {
                                // SMB/AFP — mount via native macOS
                                if let mountedURL = await SMBMounter.shared.mountShare(connectURL) {
                                    appState.updatePath(mountedURL.path, for: side)
                                }
                            } else if scheme == "sftp" || scheme == "ftp" {
                                // SFTP/FTP — RemoteConnectionManager already connected by View
                                let manager = RemoteConnectionManager.shared
                                if manager.isConnected, let conn = manager.activeConnection {
                                    appState.updatePath(conn.provider.mountPath, for: side)
                                    await appState.refreshRemoteFiles(for: side)
                                }
                            }
                            // Panel stays open — user closes it manually
                        }
                    }
                    // Wire navigate callback for Network panel
                    NetworkNeighborhoodCoordinator.shared.onNavigate = { shareURL in
                        Task { @MainActor in
                            let side = appState.focusedPanel
                            // file:// — already mounted volume, navigate directly
                            if shareURL.isFileURL {
                                appState.updatePath(shareURL.path, for: side)
                                NetworkNeighborhoodCoordinator.shared.close()
                                return
                            }
                            // smb:/afp:// — mount silently, navigate on success
                            // SMBMounter.mountShare no longer falls back to Finder
                            if let mountedURL = await SMBMounter.shared.mountShare(shareURL) {
                                appState.updatePath(mountedURL.path, for: side)
                                NetworkNeighborhoodCoordinator.shared.close()
                            }
                            // If mount failed — leave panel open so user can try Sign In
                        }
                    }
                }

                .toolbarBackground(Material.thin, for: ToolbarPlacement.windowToolbar)
                .toolbarBackgroundVisibility(Visibility.visible, for: ToolbarPlacement.windowToolbar)
                .onChange(of: scenePhase) {
                    if scenePhase == .background {
                        Task { await BookmarkStore.shared.stopAll() }
                    }
                }
                .toolbar {
                    AppToolbarContent(app: self)  // menuBarToggle included inside
                    toolBarItemBuildInfo()
                }
                // ToolbarRightClickMonitor started in AppDelegate.applicationDidFinishLaunching
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
                // MARK: - Network Neighborhood — handled via NetworkNeighborhoodCoordinator (NSPanel)
                // No .sheet here — panel opens independently, movable, resizable, persists position
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
    func toolBarItemRefresh() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "arrow.triangle.2.circlepath",
                help: HotKeyStore.shared.helpText("Refresh file lists", for: .refreshPanels)
            ) {
                log.debug("Refresh button clicked")
                appState.forceRefreshBothPanels()
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    // MARK: - Hidden files toggle (macOS HIG)
    func toolBarItemHidden() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarToggleButton(
                systemImage: "eye.slash",
                activeImage: "eye.fill",
                helpActive: HotKeyStore.shared.helpText("Hide hidden files", for: .toggleHiddenFiles),
                helpInactive: HotKeyStore.shared.helpText("Show hidden files", for: .toggleHiddenFiles),
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
    func toolBarOpenWith() -> ToolbarItem<(), some View> {
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

    // MARK: - Network Neighborhood button
    func toolBarItemNetwork() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "network",
                help: "Network Neighborhood (\u{2318}N)"
            ) {
                log.debug("Network Neighborhood button clicked")
                NetworkNeighborhoodCoordinator.shared.toggle()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    // MARK: - Connect to Server button
    func toolBarItemConnectToServer() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            ToolbarButton(
                systemImage: "server.rack",
                help: "Connect to Server (\u{2303}N)"
            ) {
                log.debug("Connect to Server button clicked")
                ConnectToServerCoordinator.shared.toggle()
            }
        }
    }

    // MARK: - Find Files button (macOS HIG — search icon)
    func toolBarItemSearch() -> ToolbarItem<(), some View> {
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
    func toolBarItemSwapPanels() -> ToolbarItem<(), some View> {
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
    func toolBarItemCompare() -> ToolbarItem<(), some View> {
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

    // MARK: - Menu Bar toggle — fixed, always in toolbar, not removable
    func toolBarItemMenuBarToggle() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            let isOn = ToolbarStore.shared.menuBarVisible
            Button {
                ToolbarStore.shared.menuBarVisible.toggle()
            } label: {
                Image(systemName: isOn ? "menubar.rectangle" : "menubar.rectangle")
                    .symbolVariant(isOn ? .none : .slash)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
            }
            .help(isOn ? "Hide menu bar" : "Show menu bar")
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
    /// Launch DirEqual via AppleScript — activate DirEqual directly, set paths via text fields.
    /// No Finder involvement, no Finder windows, no Finder activate.
    private static func launchDirEqualViaFinder(leftPath: String, rightPath: String, frame: NSRect?) {
        log.debug("\(#function) left=\(leftPath) right=\(rightPath)")
        let script = """
        tell application "DirEqual" to activate
        delay 0.5
        tell application "System Events"
            tell process "DirEqual"
                if (count windows) = 0 then
                    tell application "System Events"
                        keystroke "n" using {command down}
                    end tell
                    delay 0.5
                end if
                set value of text field 1 of group 1 of window 1 to \(leftPath.appleScriptQuoted)
                set value of text field 2 of group 1 of window 1 to \(rightPath.appleScriptQuoted)
            end tell
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        if let err {
            log.error("[Compare] DirEqual launch: \(err["NSAppleScriptErrorMessage"] ?? err)")
            return
        }
        log.info("[Compare] DirEqual activated, paths set — waiting for ready ✓")
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
        log.debug("\(#function) left=\(left) right=\(right)")
        let leftURL  = URL(fileURLWithPath: left).standardized
        let rightURL = URL(fileURLWithPath: right).standardized
        var isDir: ObjCBool = false
        let comparingDirs = FileManager.default.fileExists(atPath: leftURL.path, isDirectory: &isDir) && isDir.boolValue

        if comparingDirs {
            // Directories → DiffMerge (two-panel dir comparison)
            let diffMergeCandidates = [
                "/Applications/DiffMerge.app",
                "\(NSHomeDirectory())/Applications/DiffMerge.app",
            ]
            if let diffMergeApp = diffMergeCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                let diffMergeBin = "\(diffMergeApp)/Contents/MacOS/DiffMerge"
                // Remove macOS quarantine attributes silently — required after brew install
                Self.removeQuarantine(atPath: diffMergeApp)
                // Apply saved preferences if not yet configured
                Self.applyDiffMergeConfigIfNeeded()
                let task = Process()
                task.executableURL = URL(fileURLWithPath: diffMergeBin)
                task.arguments = ["--nosplash", leftURL.path, rightURL.path]
                do {
                    try task.run()
                    log.info("[Compare] launched DiffMerge from \(diffMergeApp) ✓")
                    Self.waitForAppReady(processName: "DiffMerge", frame: NSApp.mainWindow?.frame)
                    return
                } catch {
                    log.error("[Compare] DiffMerge: \(error.localizedDescription)")
                }
            }
            // Fallback for dirs
            Self.offerInstallDiffMerge()
        } else {
            // Files → FileMerge via opendiff
            let opendiff = "/usr/bin/opendiff"
            if FileManager.default.fileExists(atPath: opendiff) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: opendiff)
                task.arguments = [leftURL.path, rightURL.path]
                do {
                    try task.run()
                    log.info("[Compare] launched FileMerge (files) ✓")
                    Self.waitForAppReady(processName: "FileMerge", frame: NSApp.mainWindow?.frame)
                    return
                } catch {
                    log.error("[Compare] opendiff: \(error.localizedDescription)")
                }
            }
            // Fallback for files
            Self.offerInstallXcode()
        }
    }

    /// Poll until the given app's window appears, then activate and position it over MiMiNavigator.
    private static func waitForAppReady(processName: String, frame: NSRect?, attempt: Int = 0) {
        log.debug("\(#function) app=\(processName) attempt=\(attempt)")
        let maxAttempts = 16
        let interval    = 0.5

        let checkScript = """
        tell application "System Events"
            if exists process "\(processName)" then
                return (count windows of process "\(processName)") as string
            end if
            return "0"
        end tell
        """
        var err: NSDictionary?
        let result = NSAppleScript(source: checkScript)?.executeAndReturnError(&err)
        let windowCount = Int(result?.stringValue ?? "0") ?? 0

        guard windowCount > 0 else {
            guard attempt < maxAttempts else {
                log.warning("[Compare] \(processName) window never appeared")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                waitForAppReady(processName: processName, frame: frame, attempt: attempt + 1)
            }
            return
        }

        let f = frame ?? NSRect(x: 100, y: 100, width: 1200, height: 800)
        let screenH = NSScreen.main?.frame.height ?? 1080
        let wx = Int(f.origin.x)
        let wy = Int(screenH - f.origin.y - f.height)
        let ww = Int(f.width)
        let wh = Int(f.height)

        let posScript = """
        tell application "\(processName)" to activate
        delay 0.2
        tell application "System Events"
            tell process "\(processName)"
                set position of window 1 to {\(wx), \(wy)}
                set size of window 1 to {\(ww), \(wh)}
            end tell
        end tell
        """
        var posErr: NSDictionary?
        NSAppleScript(source: posScript)?.executeAndReturnError(&posErr)
        if let posErr {
            log.warning("[Compare] \(processName) position: \(posErr["NSAppleScriptErrorMessage"] ?? posErr)")
        } else {
            log.info("[Compare] \(processName) ready after \(attempt) poll(s), positioned ✓")
        }
    }

    /// Copy bundled DiffMerge preferences to ~/Library/Preferences if not yet configured.
    /// Detects "unconfigured" state by absence of [Folder/Color/Different] section.
    private static func applyDiffMergeConfigIfNeeded() {
        log.debug("\(#function)")
        let prefPath = NSHomeDirectory() + "/Library/Preferences/SourceGear DiffMerge Preferences"
        let existing = (try? String(contentsOfFile: prefPath, encoding: .utf8)) ?? ""
        // Already has user color config — don't overwrite
        guard !existing.contains("[Folder/Color/Different]") else {
            log.debug("[DiffMerge] config already applied, skipping")
            return
        }
        do {
            try diffMergeDefaultConfig.write(toFile: prefPath, atomically: true, encoding: .utf8)
            log.info("[DiffMerge] default config written to \(prefPath) ✓")
        } catch {
            log.error("[DiffMerge] failed to write config: \(error.localizedDescription)")
        }
    }

    // MARK: - Bundled DiffMerge preferences (exported from developer's configured instance)
    private static let diffMergeDefaultConfig = """
    [Window]
    [Window/Size]
    [Window/Size/Blank]
    w=1358
    h=1059
    maximized=0
    [Window/Size/Folder]
    w=1358
    h=1059
    maximized=0
    [Revision]
    Check=1771462638
    [Folder]
    ShowFlags=31
    [Folder/Printer]
    Font=14:70:SF Pro Display
    [Folder/Color]
    [Folder/Color/Different]
    bg=16242133
    [License]
    Check=1771463713
    [File]
    Font=14:70:SF Pro Display
    [File/Ruleset]
    Serialized=004207024cffffffff0353090000005f44656661756c745f0453010000002a054200064c00000000174c00000000184c00000000154201124c0e000000134c10000000164c18000000144cffffffff024c0000000003530f000000432f432b2b2f432320536f7572636504530a00000063206370702063732068054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d53030000002f5c2a0e53030000005c2a2f0f4200104200114c000000000b4c010000000c4c110000000d53020000002f2f0e53000000000f425c104201114c010000000b4c020000000c4c0e0000000d5301000000220e5301000000220f425c104201114c020000000b4c030000000c4c0e0000000d5301000000270e5301000000270f425c104201114c03000000124c18000000134c10000000164c18000000144c00000000024c0100000003531300000056697375616c20426173696320536f757263650453170000006261732066726d20636c73207662702063746c20766273054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d5301000000270e53000000000f4200104201114c000000000b4c010000000c4c0e0000000d5301000000220e5301000000220f4200104200114c01000000124c10000000134c10000000164c10000000144c01000000024c0200000003530d000000507974686f6e20536f757263650453020000007079054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d5301000000230e53000000000f4200104201114c000000000b4c010000000c4c0e0000000d5301000000220e5301000000220f4200104200114c01000000124c0c000000134c10000000164c18000000144c02000000024c0300000003530b0000004a61766120536f757263650453080000006a617661206a6176054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d53030000002f5c2a0e53030000005c2a2f0f4200104200114c000000000b4c010000000c4c110000000d53020000002f2f0e53000000000f425c104201114c010000000b4c020000000c4c0e0000000d5301000000220e5301000000220f425c104201114c02000000124c18000000134c10000000164c18000000144c03000000024c0400000003530a000000546578742046696c65730453080000007478742074657874054203064c01000000174c01000000184c01000000154201124c0e000000134c10000000164c18000000144c04000000024c050000000353100000005554462d3820546578742046696c65730453080000007574662075746638054203064c2b000000174c2b000000184c2b000000154201124c0e000000134c10000000164c18000000144c05000000024c06000000035309000000584d4c2046696c6573045303000000786d6c054203064c2b000000174c2b000000184c2b0000001542010b4c000000000c4c110000000d53040000003c212d2d0e53030000002d2d3e0f4200104200114c00000000124c18000000134c10000000164c18000000144c06000000014207
    [File/Printer]
    Font=14:70:SF Pro Display
    [ExternalTools]
    Serialized=004201014201
    [Options]
    [Options/Dialog]
    InitialPage=8
    [Dialog]
    [Dialog/Color]
    CustomColors=::::::::::::::::
    [Misc]
    CheckFoldersOnActivate=1
    """

    /// Remove macOS quarantine extended attributes from an app bundle.
    /// Required after `brew install --cask diffmerge` — otherwise macOS blocks launch.
    private static func removeQuarantine(atPath path: String) {
        log.debug("\(#function) path=\(path)")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-cr", path]
        do {
            try task.run()
            task.waitUntilExit()
            log.info("[Compare] xattr -cr \(path) ✓")
        } catch {
            log.warning("[Compare] xattr failed: \(error.localizedDescription)")
        }
    }

    /// Offer to install DiffMerge via brew for directory comparison.
    @MainActor
    private static func offerInstallDiffMerge() {
        log.debug("\(#function)")
        let alert = NSAlert()
        alert.messageText = "DiffMerge Not Found"
        alert.informativeText = """
            DiffMerge is a free tool for two-panel directory comparison.

            Install via Homebrew:
              brew install --cask diffmerge

            Note: after installation macOS may block the app due to quarantine.
            MiMiNavigator removes quarantine attributes automatically on first launch.
            If you still see a warning, run manually:
              xattr -cr /Applications/DiffMerge.app
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install via brew")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let script = """
            tell application "Terminal"
                activate
                do script "brew install --cask diffmerge && (xattr -cr /Applications/DiffMerge.app 2>/dev/null || xattr -cr ~/Applications/DiffMerge.app 2>/dev/null) && echo 'DiffMerge ready ✓'"
            end tell
            """
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            log.info("[Compare] offered DiffMerge install via brew")
        }
    }

    /// Offer to install Xcode (which includes FileMerge) from the App Store.
    @MainActor
    private static func offerInstallXcode() {
        log.debug("\(#function)")
        let alert = NSAlert()
        alert.messageText = "FileMerge Not Found"
        alert.informativeText = "FileMerge is bundled with Xcode and works great for comparing files and folders.\n\nWould you like to install Xcode from the App Store?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open App Store")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/id497799835")!)
        }
        log.info("[Compare] offered Xcode via App Store")
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
