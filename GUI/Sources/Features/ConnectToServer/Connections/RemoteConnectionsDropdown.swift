// RemoteConnectionsDropdown.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Toolbar popup dropdown listing registered (S)FTP connections.
//   Each row: lamp button (connect/disconnect) + server name.
//   Double-click on name → navigate active panel to remote dir.
//   Connected = green lamp + dark green name.
//   Error = red lamp + red name.
//   Idle = grey lamp + standard color.
//   Compact, crisp monospaced font — mirrors macOS Selection popup style.

import FileModelKit
import SwiftUI


// MARK: - RemoteConnectionsDropdown
struct RemoteConnectionsDropdown: View {

    let appState: AppState

    @State private var store = RemoteServerStore.shared
    @State private var manager = RemoteConnectionManager.shared
    private var servers: [RemoteServer] { store.servers }


    // MARK: - Body
    var body: some View {
        Menu {
            if servers.isEmpty {
                Text("No servers configured")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Section("Servers") {
                    ForEach(servers) { server in
                        serverMenuRow(server)
                    }
                }
            }
            Divider()
            Button {
                ConnectToServerCoordinator.shared.open()
            } label: {
                Label("Manage Connections…", systemImage: "slider.horizontal.3")
            }
        } label: {
            dropdownLabel
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .help("Remote connections")
    }


    // MARK: - Dropdown Label (collapsed state)
    private var dropdownLabel: some View {
        let activeCount = servers.filter { manager.hasConnection(for: $0) }.count
        return TopDropdownLabel(
            title: activeCount > 0 ? "Connections · \(activeCount)" : "Connections",
            systemImage: "antenna.radiowaves.left.and.right",
            tint: activeCount > 0 ? .green : .accentColor
        )
    }


    // MARK: - Server Menu Row
    @ViewBuilder
    private func serverMenuRow(_ server: RemoteServer) -> some View {
        let connected = manager.hasConnection(for: server)

        if connected {
            connectedServerSubmenu(server)
        } else {
            disconnectedServerButton(server)
        }
    }


    // MARK: - Connected Server (submenu: Navigate / Disconnect)
    private func connectedServerSubmenu(_ server: RemoteServer) -> some View {
        Menu {
            Button {
                navigateActivePanel(to: server)
            } label: {
                Label("Open in Active Panel", systemImage: "folder")
            }
            Button {
                disconnectServer(server)
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
            }
        } label: {
            Label {
                Text("\(server.displayName) · \(server.remoteProtocol.rawValue)")
            } icon: {
                Image(systemName: "network.badge.shield.half.filled")
            }
        }
    }


    // MARK: - Disconnected Server (single action: connect)
    private func disconnectedServerButton(_ server: RemoteServer) -> some View {
        Button {
            connectServer(server)
        } label: {
            Label {
                Text("\(server.displayName) · \(server.remoteProtocol.rawValue)")
            } icon: {
                Image(systemName: "network")
            }
        }
    }


    // MARK: - Connect
    private func connectServer(_ server: RemoteServer) {
        let password = RemoteServerKeychain.loadPassword(for: server)
        guard !password.isEmpty else {
            ConnectToServerCoordinator.shared.openWithFocus(serverID: server.id, field: "password")
            return
        }
        showConnectProgress(server: server)
        Task {
            await manager.connect(to: server, password: password)
            if manager.hasConnection(for: server) {
                handleConnectSuccess(server)
            } else {
                handleConnectFailure(server)
            }
        }
    }


    // MARK: - Connect Success
    private func handleConnectSuccess(_ server: RemoteServer) {
        let pp = ProgressPanel.shared
        pp.appendLog("✅ Authentication successful")
        pp.appendLog("Session established with \(server.host):\(server.port)")
        pp.appendLog("Remote path: \(server.remotePath.isEmpty ? "/" : server.remotePath)")
        pp.finish(success: true, message: "Connected — \(server.displayName)")
        log.info("[DropdownConnect] success \(server.displayName)")
        navigateActivePanel(to: server)
    }


    // MARK: - Connect Failure
    private func handleConnectFailure(_ server: RemoteServer) {
        let refreshed = RemoteServerStore.shared.servers.first(where: { $0.id == server.id }) ?? server
        let result = refreshed.lastResult
        let detail = refreshed.lastErrorDetail ?? result.rawValue
        let summary = ConnectionErrorFormatter.summary(result: result, detail: detail, server: server)
        let pp = ProgressPanel.shared
        pp.appendLog("❌ Connection failed: \(result.rawValue)")
        pp.appendLog("Detail:")
        ConnectionErrorFormatter.logLines(from: detail).forEach { pp.appendLog($0) }
        if result == .authFailed {
            pp.appendLog("Hint: check username/password or key path")
        } else if result == .timeout {
            pp.appendLog("Hint: host unreachable or firewall blocking port \(server.port)")
        } else if result == .refused {
            pp.appendLog("Hint: \(server.remoteProtocol.rawValue) service not running on \(server.host):\(server.port)")
        }
        pp.finish(success: false, message: "Failed — \(summary)")
        log.warning("[DropdownConnect] failed \(server.displayName): \(detail)")

        if result == .authFailed {
            ConnectToServerCoordinator.shared.openWithFocus(serverID: server.id, field: "password")
        }
    }


    // MARK: - Show Connect Progress (verbose)
    private func showConnectProgress(server: RemoteServer) {
        let pp = ProgressPanel.shared
        pp.show(
            icon: "link",
            title: "Connecting to \(server.displayName)…",
            status: "\(server.remoteProtocol.rawValue) → \(server.host):\(server.port)"
        )
        pp.appendLog("Protocol: \(server.remoteProtocol.rawValue)")
        pp.appendLog("Host: \(server.host)")
        pp.appendLog("Port: \(server.port)")
        pp.appendLog("User: \(server.user.isEmpty ? "(none)" : server.user)")
        pp.appendLog("Auth: \(server.authType.rawValue)")
        pp.appendLog("Remote path: \(server.remotePath.isEmpty ? "/" : server.remotePath)")
        pp.appendLog("Connecting…")
    }


    // MARK: - Navigate Active Panel
    private func navigateActivePanel(to server: RemoteServer) {
        guard let conn = manager.connection(for: server) else { return }
        manager.setActive(id: conn.id)
        let mountPath = conn.provider.mountPath
        guard let targetURL = resolvedMountedOrRemoteURL(from: mountPath) else {
            log.error("[DropdownNav] bad mountPath: \(mountPath)")
            return
        }
        let side = appState.focusedPanel
        Task {
            await navigatePanel(to: targetURL, for: side)
        }
        log.info("[DropdownNav] \(side) → \(server.displayName)")
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


    // MARK: - Disconnect
    private func disconnectServer(_ server: RemoteServer) {
        guard let conn = manager.connection(for: server) else { return }

        let pp = ProgressPanel.shared
        pp.show(
            icon: "xmark.circle",
            title: "Disconnecting \(server.displayName)…",
            status: "Closing \(server.remoteProtocol.rawValue) session"
        )
        pp.appendLog("Host: \(server.host):\(server.port)")
        pp.appendLog("Session ID: \(conn.id)")
        pp.appendLog("Disconnecting…")

        Task {
            let disconnectedMountPath = conn.provider.mountPath
            await fallbackPanelsFromServer(server, disconnectedMountPath: disconnectedMountPath)
            pp.appendLog("Panels restored from history")
            await manager.disconnect(id: conn.id)
            pp.appendLog("Session closed")
            pp.finish(success: true, message: "Disconnected from \(server.displayName)")
            log.info("[DropdownDisconnect] \(server.displayName)")
        }
    }


    // MARK: - Fallback all panels showing this server
    private func fallbackPanelsFromServer(_ server: RemoteServer, disconnectedMountPath: String) async {
        let scheme = server.remoteProtocol.urlScheme
        let host = server.host.lowercased()

        for side in FavPanelSide.allCases {
            let panelURL = side == .left ? appState.leftURL : appState.rightURL
            guard isURLMatchingServer(panelURL, scheme: scheme, host: host, mountPath: disconnectedMountPath) else { continue }
            await restorePanelAfterDisconnect(side, server: server, disconnectedMountPath: disconnectedMountPath)
            log.info("[DropdownFallback] \(side) restored from \(server.displayName)")
        }
    }


    // MARK: - URL Matching
    private func isURLMatchingServer(_ url: URL, scheme: String, host: String, mountPath: String) -> Bool {
        if url.scheme?.lowercased() == scheme && url.host?.lowercased() == host { return true }
        return urlMatchesMountPath(url, mountPath: mountPath)
    }

    private func urlMatchesMountPath(_ url: URL, mountPath: String) -> Bool {
        guard !mountPath.isEmpty, mountPath.hasPrefix("/") else { return false }
        let panelPath = NSString(string: url.path).standardizingPath
        let normalizedMountPath = NSString(string: mountPath).standardizingPath
        return panelPath == normalizedMountPath || panelPath.hasPrefix(normalizedMountPath + "/")
    }

    private func restorePanelAfterDisconnect(_ side: FavPanelSide, server: RemoteServer, disconnectedMountPath: String) async {
        if let historyURL = nearestHistoryFallback(for: side, server: server, disconnectedMountPath: disconnectedMountPath) {
            await restorePanel(side, to: historyURL)
            return
        }
        await appState.restoreLocalPath(for: side)
    }

    private func nearestHistoryFallback(for side: FavPanelSide, server: RemoteServer, disconnectedMountPath: String) -> URL? {
        let history = appState.navigationHistory(for: side)
        return history.nearestPreviousEntry { candidate in
            !isURLMatchingServer(
                candidate,
                scheme: server.remoteProtocol.urlScheme,
                host: server.host.lowercased(),
                mountPath: disconnectedMountPath
            )
        }
    }

    private func restorePanel(_ side: FavPanelSide, to url: URL) async {
        await navigatePanel(to: url, for: side)
    }


    // MARK: - Connection Error via ProgressPanel
    private func showConnectionError(server: RemoteServer, message: String) {
        ProgressPanel.shared.show(
            icon: "exclamationmark.triangle",
            title: server.displayName,
            status: message
        )
        ProgressPanel.shared.finish(success: false, message: message)
    }


}
