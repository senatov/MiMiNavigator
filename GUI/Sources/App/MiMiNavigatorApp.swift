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
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(appState: appState)
        }
    }

    // MARK: - Refresh button with animation
    fileprivate func toolBarItemRefresh() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            AnimatedToolbarButton(
                systemImage: "arrow.triangle.2.circlepath",
                help: "Refresh file lists (⌘R)",
                shortcut: "r",
                modifiers: .command
            ) {
                log.debug("Refresh button clicked")
                appState.forceRefreshBothPanels()
            }
        }
    }

    // MARK: - Hidden files toggle with animation
    fileprivate func toolBarItemHidden() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            AnimatedToolbarButton(
                systemImage: "eye.slash",
                activeImage: "eye.fill",
                help: showHiddenFiles ? "Hide hidden files (⌘.)" : "Show hidden files (⌘.)",
                shortcut: ".",
                modifiers: .command,
                isToggle: true,
                isActive: $showHiddenFiles,
                activeColor: .green,
                inactiveColor: .secondary
            ) {
                log.debug("Hidden toggle clicked")
                showHiddenFiles.toggle()
                UserPreferences.shared.snapshot.showHiddenFiles = showHiddenFiles
                appState.forceRefreshBothPanels()
            }
        }
    }

    // MARK: - Open With button with animation
    fileprivate func toolBarOpenWith() -> ToolbarItem<(), some View> {
        return ToolbarItem(placement: .automatic) {
            AnimatedToolbarButton(
                systemImage: "arrow.up.forward.app",
                help: "Open file / Get Info for directory (⌘O)",
                shortcut: "o",
                modifiers: .command
            ) {
                log.debug("OpenWith button clicked")
                appState.openSelectedItem()
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
