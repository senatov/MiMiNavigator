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
    @State private var appState = AppState()
    @State private var dragDropManager = DragDropManager()
    @State private var contextMenuCoordinator = ContextMenuCoordinator.shared
    @State private var showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// App version from CFBundleShortVersionString (e.g. "0.9.4")
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    // MARK: -
    init() {
        AppLogger.initialize()
        log.debug("---- Logger initialized ------")
        // BookmarkStore.restoreAll() is called in AppDelegate.applicationDidFinishLaunching
        // to ensure NSApplication is fully initialized before sandbox token requests.
        Task { await RemoteConnectionManager.shared.connectOnStartIfNeeded() }
    }

    // MARK: -
    var body: some Scene {
        WindowGroup {
            DuoFilePanelView()
                .environment(appState)
                .environment(dragDropManager)
                .contextMenuDialogs(coordinator: contextMenuCoordinator, appState: appState)
                .navigationTitle("MiMiNavigator V \(Self.appVersion)")
                .onAppear {
                    appDelegate.bind(appState)
                    AppStateProvider.shared = appState
                    showHiddenFiles = UserPreferences.shared.snapshot.showHiddenFiles
                    // Wire connect callback for ConnectToServer panel
                    ConnectToServerCoordinator.shared.onDisconnect = {
                        Task { @MainActor in
                            // Restore whichever panel(s) are showing remote content
                            if AppState.isRemotePath(appState.leftURL) {
                                await appState.restoreLocalPath(for: PanelSide.left)
                            }
                            if AppState.isRemotePath(appState.rightURL) {
                                await appState.restoreLocalPath(for: PanelSide.right)
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
                                    appState.updatePath(mountedURL, for: side)
                                }
                            } else if scheme == "sftp" || scheme == "ftp" {
                                // SFTP/FTP — RemoteConnectionManager already connected by View
                                let manager = RemoteConnectionManager.shared
                                if manager.isConnected, let conn = manager.activeConnection {
                                    let mountURL = URL(fileURLWithPath: conn.provider.mountPath)
                                    appState.updatePath(mountURL, for: side)
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
                                appState.updatePath(shareURL, for: side)
                                NetworkNeighborhoodCoordinator.shared.close()
                                return
                            }
                            // smb:/afp:// — mount silently, navigate on success
                            // SMBMounter.mountShare no longer falls back to Finder
                            if let mountedURL = await SMBMounter.shared.mountShare(shareURL) {
                                appState.updatePath(mountedURL, for: side)
                                NetworkNeighborhoodCoordinator.shared.close()
                            }
                            // If mount failed — leave panel open so user can try Sign In
                        }
                    }
                }

                // No .toolbarBackground — our ToolbarButtonGroup provides its own framing
                .onChange(of: scenePhase) {
                    if scenePhase == .background {
                        Task { await BookmarkStore.shared.stopAll() }
                    }
                }
                .toolbar {
                    AppToolbarContent(app: self, appState: appState)
                        .sharedBackgroundVisibility(.hidden)  // menuBarToggle included inside
                    AppBuildInfo.toolBarItem()
                        .sharedBackgroundVisibility(.hidden)
                }
                .glassEffect(Glass.identity)
                // ToolbarRightClickMonitor started in AppDelegate.applicationDidFinishLaunching
                // MARK: - File Transfer Confirmation Dialog
                .sheet(
                    isPresented: Binding(
                        get: { dragDropManager.showConfirmationDialog },
                        set: { dragDropManager.showConfirmationDialog = $0 }
                    )
                ) {
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
        }
        .defaultSize(width: 1200, height: 700)
        .defaultPosition(.center)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(appState: appState)
            SettingsCommands()
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   Toolbar Icon / Toggle Factories
    // MARK: - ═══════════════════════════════════════

    /// Creates a ToolbarButton for a given ToolbarItemID with action closure.
    func makeToolbarIcon(_ id: ToolbarItemID, action: @escaping () -> Void) -> some View {
        ToolbarButton(systemImage: id.systemImage, help: id.helpText, action: action)
    }

    /// Creates a ToolbarToggleButton for specific known toggle items.
    @ViewBuilder
    func makeToolbarToggle(_ id: ToolbarItemID) -> some View {
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

    func performRefresh() {
        log.debug("Refresh button clicked")
        appState.forceRefreshBothPanels()
    }

    func performToggleHidden() {
        log.debug("Hidden toggle clicked")
        showHiddenFiles.toggle()
        UserPreferences.shared.snapshot.showHiddenFiles = showHiddenFiles
        appState.forceRefreshBothPanels()
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
        ConnectToServerCoordinator.shared.toggle()
    }

    func performFindFiles() {
        log.debug("Search button clicked")
        let panel = appState.focusedPanel
        let path = appState.path(for: panel)
        let selectedFile = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
        FindFilesCoordinator.shared.toggle(searchPath: path, selectedFile: selectedFile, appState: appState)
    }

    func performSettings() {
        log.debug("Settings button clicked")
        SettingsCoordinator.shared.toggle()
    }

}
