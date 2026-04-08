// MiMiNavigatorApp.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: App entry point. Wires toolbar, panels, drag-drop, network mount callbacks.
//   Build badge → App/AppBuildInfo.swift
//   Diff/compare → Services/DiffTool/DiffToolLauncher.swift
//   SettingsCommands → App/AppCommands.swift

import AppKit
import FileModelKit
import NetworkKit
import SwiftUI

@main
struct MiMiNavigatorApp: App {
    // MARK: - State

    @State private var appState = AppState()
    @State private var dragDropManager = DragDropManager()
    @State private var contextMenuCoordinator = ContextMenuCoordinator.shared
    @State private var showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
    @State private var showAutomationOnboarding = false

    // MARK: - Lifecycle State

    @State private var didRestoreMainWindowFrame = false
    @State private var didBindAppState = false
    @State private var didWireCoordinatorCallbacks = false

    // MARK: - Environment

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// App version from CFBundleShortVersionString (e.g. "0.9.4")
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    // MARK: -
    init() {
        AppLogger.initialize()
    }

    // MARK: - Toolbar
    var appToolbarContent: some ToolbarContent {
        Group {
            AppToolbarContent(app: self, appState: appState)
                .sharedBackgroundVisibility(.hidden)
            AppBuildInfo.toolBarItem()
                .sharedBackgroundVisibility(.hidden)
        }
    }

    // MARK: - Overlay
    @ViewBuilder
    var batchProgressOverlay: some View {
        log.debug(#function)
        if BatchOperationManager.shared.showProgressDialog,
            let state = BatchOperationManager.shared.currentOperation
        {
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

    // MARK: - App Lifecycle Helpers
    func handleMainWindowAppear() {
        log.debug(#function)
        restoreMainWindowFrameIfNeeded()
        bindAppStateIfNeeded()
        wireCoordinatorCallbacks()
    }

    private func restoreMainWindowFrameIfNeeded() {
        log.debug(#function)
        guard !didRestoreMainWindowFrame else { return }
        guard let win = NSApp.windows.first(where: { !($0 is NSPanel) }) else { return }

        if let savedFrame = StatePersistence.restoreWindowFrame() {
            win.setFrame(savedFrame, display: true, animate: false)
            StatePersistence.lastKnownWindowFrame = savedFrame
            log.info("[App] window frame restored: \(Int(savedFrame.width))x\(Int(savedFrame.height))")
        } else {
            StatePersistence.lastKnownWindowFrame = win.frame
        }

        win.setFrameAutosaveName("MiMiNavigator.MainWindow")
        didRestoreMainWindowFrame = true
    }

    private func bindAppStateIfNeeded() {
        guard !didBindAppState else { return }
        appDelegate.bind(appState)
        AppStateProvider.shared = appState
        showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
        didBindAppState = true
    }

    private func wireCoordinatorCallbacks() {
        log.debug(#function)
        guard !didWireCoordinatorCallbacks else { return }
        ConnectToServerCoordinator.shared.onDisconnect = {
            Task { @MainActor in
                await handleRemoteDisconnect()
            }
        }

        ConnectToServerCoordinator.shared.onConnect = { url, password in
            Task { @MainActor in
                await handleRemoteConnect(url: url, password: password)
            }
        }

        NetworkNeighborhoodCoordinator.shared.onNavigate = { shareURL in
            Task { @MainActor in
                await handleNetworkNavigate(shareURL)
            }
        }

        didWireCoordinatorCallbacks = true
    }

    private func handleScenePhaseChange() {
        log.debug(#function)
        if scenePhase == .background {
            Task {
                await BookmarkStore.shared.stopAll()
            }
        }
    }

    private func handleRemoteDisconnect() async {
        if AppState.isRemotePath(appState.leftURL) {
            await appState.restoreLocalPath(for: FavPanelSide.left)
        }

        if AppState.isRemotePath(appState.rightURL) {
            await appState.restoreLocalPath(for: FavPanelSide.right)
        }
    }

    private func handleRemoteConnect(url: URL, password: String) async {
        log.debug(#function)
        let side = appState.focusedPanel
        let connectURL = buildAuthenticatedConnectURL(from: url, password: password)
        let scheme = url.scheme ?? ""
        log.info("[ConnectToServer] connecting \(scheme)://\(url.host ?? "")")
        if scheme == "smb" || scheme == "afp" {
            await connectMountedShare(connectURL, for: side)
            return
        }
        if scheme == "sftp" || scheme == "ftp" {
            await connectRemoteProvider(for: side)
        }
    }

    private func buildAuthenticatedConnectURL(from url: URL, password: String) -> URL {
        log.debug(#function)
        guard !password.isEmpty,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return url
        }

        if components.user == nil || components.user?.isEmpty == true {
            components.user = "guest"
        }
        components.password = password
        return components.url ?? url
    }

    private func connectMountedShare(_ url: URL, for side: FavPanelSide) async {
        if let mountedURL = await SMBMounter.shared.mountShare(url) {
            appState.updatePath(mountedURL, for: side)
        }
    }

    private func connectRemoteProvider(for side: FavPanelSide) async {
        let manager = RemoteConnectionManager.shared
        guard manager.isConnected, let conn = manager.activeConnection else { return }

        let mountPath = conn.provider.mountPath
        guard let remoteURL = URL(string: mountPath) else {
            log.error("[ConnectToServer] bad mountPath URL: \(mountPath)")
            return
        }

        appState.updatePath(remoteURL, for: side)
        await appState.refreshRemoteFiles(for: side)
    }

    private func handleNetworkNavigate(_ shareURL: URL) async {
        let side = appState.focusedPanel

        if shareURL.isFileURL {
            appState.updatePath(shareURL, for: side)
            NetworkNeighborhoodCoordinator.shared.close()
            return
        }

        if let mountedURL = await SMBMounter.shared.mountShare(shareURL) {
            appState.updatePath(mountedURL, for: side)
            NetworkNeighborhoodCoordinator.shared.close()
        }
    }

    // MARK: - Transfer Confirmation Helpers
    @ViewBuilder
    func transferConfirmationDialog(for operation: FileTransferOperation) -> some View {
        FileTransferConfirmationDialog(operation: operation) { action in
            executePendingTransfer(action)
        }
    }

    private func executePendingTransfer(_ action: FileTransferAction) {
        let manager = dragDropManager
        let state = appState

        Task { @MainActor in
            await manager.executeTransfer(action: action, appState: state)
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   Toolbar Icon / Toggle Factories
    // MARK: - ═══════════════════════════════════════

    /// Creates a ToolbarButton for a given ToolbarItemID with action closure.
    private func makeToolbarIcon(_ id: ToolbarItemID, action: @escaping () -> Void) -> some View {
        ToolbarButton(systemImage: id.systemImage, help: id.helpText, action: action)
    }

    /// Creates a ToolbarToggleButton for specific known toggle items.
    @ViewBuilder
    private func makeToolbarToggle(_ id: ToolbarItemID) -> some View {
        log.debug(#function)
        switch id {
            case .hiddenFiles:
                ToolbarToggleButton(
                    systemImage: "eye.slash",
                    activeImage: "eye.fill",
                    helpActive: HotKeyStore.shared.helpText("Hide hidden files", for: .toggleHiddenFiles),
                    helpInactive: HotKeyStore.shared.helpText("Show hidden files", for: .toggleHiddenFiles),
                    isActive: Binding(get: { showHiddenFiles }, set: { _ in })
                ) {
                    performToggleHidden()
                }
            case .menuBarToggle:
                ToolbarToggleButton(
                    systemImage: "menubar.rectangle",
                    activeImage: "menubar.rectangle",
                    helpActive: "Hide menu bar",
                    helpInactive: "Show menu bar",
                    isActive: Binding(get: { ToolbarStore.shared.menuBarVisible }, set: { _ in })
                ) {
                    ToolbarStore.shared.menuBarVisible.toggle()
                }
            default:
                EmptyView()
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   Toolbar Actions (called from AppToolbarContent)
    // MARK: - ═══════════════════════════════════════

    private func performRefresh() {
        log.debug("Refresh button clicked")
        appState.forceRefreshBothPanels()
    }

    private func performToggleHidden() {
        log.debug("Hidden toggle clicked")
        appState.toggleShowHiddenFiles()
        showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
    }

    private func performOpenWith() {
        log.debug("OpenWith button clicked")
        appState.openSelectedItem()
    }

    private func performSwapPanels() {
        log.debug("Swap panels button clicked")
        appState.swapPanels()
    }

    // MARK: - performCompare
    private func performCompare() {
        log.debug("Compare button clicked")
        let panel = appState.focusedPanel
        let left = appState.leftPath
        let right = appState.rightPath
        let leftFile = appState.selectedLeftFile
        let rightFile = appState.selectedRightFile
        let markedOnFocused = appState.markedCustomFiles(for: panel).filter { !ParentDirectoryEntry.isParentEntry($0) }
        let lp: String
        let rp: String
        if markedOnFocused.count == 2 {
            lp = markedOnFocused[0].urlValue.path
            rp = markedOnFocused[1].urlValue.path
        } else if case (.some(let l), .some(let r)) = (leftFile, rightFile), !l.isDirectory, !r.isDirectory {
            lp = l.urlValue.path
            rp = r.urlValue.path
        } else {
            lp = left
            rp = right
        }
        DiffToolLauncher.launch(left: lp, right: rp)
    }

    private func performNetwork() {
        log.debug("Network Neighborhood button clicked")
        NetworkNeighborhoodCoordinator.shared.toggle()
    }

    private func performConnectServer() {
        log.debug("Connect to Server button clicked")
        ConnectToServerCoordinator.shared.toggle()
    }

    private func performFindFiles() {
        log.debug("Search button clicked")
        let panel = appState.focusedPanel
        let path = appState.path(for: panel)
        let selectedFile = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
        FindFilesCoordinator.shared.toggle(searchPath: path, selectedFile: selectedFile, appState: appState)
    }

    private func performSettings() {
        log.debug("Settings button clicked")
        SettingsCoordinator.shared.toggle()
    }
}
