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

    @State var appState = AppState()
    @State var dragDropManager = DragDropManager()
    @State var cntMenuCoord = CntMenuCoord.shared
    @State var showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
    @State var showAutomationOnboarding = false
    @State var showFullDiskOnboarding = false
    @State var showGitHubStarPrompt = false
    @State var isFinderSidebarVisible = false
    @State var gitHubStarStore = GitHubStarAcknowledgementStore.shared

    // MARK: - Lifecycle State

    @State var didBindAppState = false
    @State var didWireCoordinatorCallbacks = false
    @State var didRestoreStartupConnection = false
    @State var didScheduleGitHubStarPrompt = false

    // MARK: - Environment

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase

    /// App version from CFBundleShortVersionString (e.g. "0.9.4")
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    // MARK: -
    init() {
        AppLogger.initialize()
        GoogleDriveCredentialBootstrap.ensureLocalCredentials()
    }

    // MARK: - Toolbar
    var appToolbarContent: some ToolbarContent {
        Group {
            AppToolbarContent(app: self, appState: appState)
                .sharedBackgroundVisibility(.hidden)
            AppBuildInfo.toolBarItem()
                .sharedBackgroundVisibility(.hidden)
            if !gitHubStarStore.isAcknowledged {
                ToolbarItem(placement: .status) {
                    GitHubStarBadge {
                        showGitHubStarPrompt = true
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    // MARK: - App Lifecycle Helpers
    func handleMainWindowAppear() {
        log.debug(#function)
        WindowFrameRestorer.shared.scheduleRestore()
        bindAppStateIfNeeded()
        wireCoordinatorCallbacks()
        AppManagedMountCleanupScheduler.start()
    }

    func bindAppStateIfNeeded() {
        guard !didBindAppState else { return }
        appDelegate.bind(appState)
        AppStateProvider.shared = appState
        showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
        didBindAppState = true
    }

    func wireCoordinatorCallbacks() {
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

        RemoteConnectionManager.shared.onConnectionActivated = { connection in
            Task { @MainActor in
                await handleActivatedConnection(connection)
            }
        }

        didWireCoordinatorCallbacks = true
        restoreStartupConnectionIfNeeded()
    }

    func handleScenePhaseChange() {
        log.debug(#function)
        if scenePhase == .background {
            Task {
                await BookmarkStore.shared.stopAll()
            }
        }
    }

    func handleRemoteDisconnect() async {
        if AppState.isRemotePath(appState.leftURL) {
            await appState.restoreLocalPath(for: FavPanelSide.left)
        }

        if AppState.isRemotePath(appState.rightURL) {
            await appState.restoreLocalPath(for: FavPanelSide.right)
        }
        await AppState.cleanupStaleAppManagedMounts()
    }

    private func handleRemoteConnect(url: URL, password: String) async {
        log.debug(#function)
        let side = appState.focusedPanel
        let connectURL = buildAuthenticatedConnectURL(from: url, password: password)
        let scheme = url.scheme ?? ""
        log.info("[ConnectToServer] connecting \(scheme)://\(url.host ?? "")")
        if scheme == "smb" || scheme == "afp" {
            if scheme == "smb",
               let activeConnection = RemoteConnectionManager.shared.activeConnection,
               activeConnection.server.remoteProtocol == .smb,
               let mountedURL = resolvedMountedOrRemoteURL(from: activeConnection.provider.mountPath)
            {
                await navigatePanel(to: mountedURL, for: side)
                return
            }
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
        do {
            let mountedURL = try await SMBMounter.shared.mountShareResult(url)
            await navigatePanel(to: mountedURL, for: side)
        } catch {
            log.error("[SMB] mount failed host='\(url.host ?? "")' path='\(url.path)' error='\(error.localizedDescription)'")
        }
    }

    private func connectRemoteProvider(for side: FavPanelSide) async {
        let manager = RemoteConnectionManager.shared
        guard manager.isConnected, let conn = manager.activeConnection else { return }
        let mountPath = conn.provider.mountPath

        guard let remoteURL = resolvedMountedOrRemoteURL(from: conn.provider.mountPath) else {
            log.error("[ConnectToServer] bad mountPath URL: \(mountPath)")
            return
        }

        await navigatePanel(to: remoteURL, for: side)
    }

    private func handleNetworkNavigate(_ shareURL: URL) async {
        let side = appState.focusedPanel

        if shareURL.isFileURL {
            await navigatePanel(to: shareURL, for: side)
            NetworkNeighborhoodCoordinator.shared.close()
            return
        }

        do {
            let mountedURL = try await SMBMounter.shared.mountShareResult(shareURL)
            await navigatePanel(to: mountedURL, for: side)
            NetworkNeighborhoodCoordinator.shared.close()
        } catch {
            log.error("[Network] mount failed host='\(shareURL.host ?? "")' path='\(shareURL.path)' error='\(error.localizedDescription)'")
            NetworkNeighborhoodCoordinator.shared.showMountFailure(for: shareURL, error: error)
        }
    }

    private func restoreStartupConnectionIfNeeded() {
        guard !didRestoreStartupConnection else { return }
        guard let connection = RemoteConnectionManager.shared.activeConnection else { return }
        didRestoreStartupConnection = true

        Task { @MainActor in
            await handleActivatedConnection(connection)
        }
    }

    private func handleActivatedConnection(_ connection: RemoteConnection) async {
        guard let targetURL = resolvedMountedOrRemoteURL(from: connection.provider.mountPath) else {
            log.error("[ConnectToServer] bad activated mountPath: \(connection.provider.mountPath)")
            return
        }

        let side = appState.focusedPanel
        await navigatePanel(to: targetURL, for: side)
    }

    private func resolvedMountedOrRemoteURL(from mountPath: String) -> URL? {
        guard !mountPath.isEmpty else { return nil }
        if mountPath.hasPrefix("/") {
            return URL(fileURLWithPath: mountPath, isDirectory: true)
        }
        return URL(string: mountPath)
    }

    private func navigatePanel(to url: URL, for side: FavPanelSide) async {
        if AppState.isRemotePath(url) {
            await appState.navigateToDirectory(url.absoluteString, on: side)
        } else {
            await appState.navigateToDirectory(url.path, on: side)
        }
    }

    // MARK: - Transfer Confirmation Helpers
    @ViewBuilder
    func transferConfirmationDialog(for operation: FileTransferOperation) -> some View {
        BatchConfirmationDialog(operation: operation) { action in
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
    func makeToolbarIcon(_ id: ToolbarItemID, action: @escaping () -> Void) -> some View {
        ToolbarButton(systemImage: id.systemImage, help: id.helpText, iconColor: toolbarIconColor(for: id), action: action)
    }

    // MARK: - Toolbar Icon Color
    private func toolbarIconColor(for id: ToolbarItemID) -> Color? {
        switch id {
            case .multiRename:
                return Color(#colorLiteral(red: 0.2470588235, green: 0.0784313725, blue: 0.3921568627, alpha: 1.0))
            default:
                return nil
        }
    }

    /// Creates a ToolbarToggleButton for specific known toggle items.
    @ViewBuilder
    func makeToolbarToggle(_ id: ToolbarItemID) -> some View {
        switch id {
            case .hiddenFiles:
                ToolbarToggleButton(
                    systemImage: "eye.slash",
                    activeImage: "eye.fill",
                    helpActive: HotKeyStore.shared.helpText("Hidden files are shown — click to hide", for: .toggleHiddenFiles),
                    helpInactive: HotKeyStore.shared.helpText("Hidden files are hidden — click to show", for: .toggleHiddenFiles),
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

    func performRefresh() {
        log.debug("Refresh button clicked")
        appState.forceRefreshBothPanels()
    }

    func performToggleHidden() {
        log.debug("Hidden toggle clicked")
        appState.toggleShowHiddenFiles()
        showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
    }

    func performOpenWith() {
        log.debug("OpenWith button clicked")
        appState.openSelectedItem()
    }

    func performSwapPanels() {
        log.debug("Swap panels button clicked")
        appState.swapPanels()
    }

    // MARK: - performCompare
    func performCompare() {
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

    func performNetwork() {
        log.debug("Network Neighborhood button clicked")
        NetworkNeighborhoodCoordinator.shared.toggle()
    }

    func performConnectServer() {
        log.debug("Connect to Server button clicked")
        ConnectToServerCoordinator.shared.open()
    }

    func performFindFiles() {
        log.debug("Search button clicked")
        let panel = appState.focusedPanel
        let path = appState.path(for: panel)
        let selectedFile = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
        FindFilesCoordinator.shared.toggle(searchPath: path, selectedFile: selectedFile, appState: appState)
    }

    func performMultiRename() {
        log.debug("[MultiRename] toolbar button clicked")
        MultiRenameCoordinator.shared.toggle(panel: appState.focusedPanel, appState: appState)
    }

    func performSettings() {
        log.debug("Settings button clicked")
        SettingsCoordinator.shared.toggle()
    }
}
