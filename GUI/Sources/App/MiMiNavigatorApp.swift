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

    /// Launch best available diff tool. Sandbox disabled in Debug — Process() works directly.
    /// Priority: FileMerge (opendiff) → kdiff3 → Beyond Compare → alert
    private func launchDiffTool(left: String, right: String) {
        let candidates: [(appPath: String, bin: String, args: [String])] = [
            ("/Applications/Xcode.app/Contents/Applications/FileMerge.app",
             "/usr/bin/opendiff", [left, right]),
            ("/Applications/kdiff3.app",
             "/Applications/kdiff3.app/Contents/MacOS/kdiff3", [left, right]),
            ("/Applications/Beyond Compare.app",
             "/Applications/Beyond Compare.app/Contents/MacOS/bcomp", [left, right]),
        ]

        for (appPath, bin, args) in candidates {
            guard FileManager.default.fileExists(atPath: appPath) else { continue }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: bin)
            task.arguments = args
            do {
                try task.run()
                log.info("[Compare] launched \(appPath.components(separatedBy: "/").last ?? bin) ✓")
                return
            } catch {
                log.error("[Compare] \(bin) failed: \(error.localizedDescription)")
            }
        }

        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "No Diff Tool Found"
            alert.informativeText = "Install Xcode (FileMerge), kdiff3, or Beyond Compare to compare files and folders."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        log.warning("[Compare] No diff tool available")
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
