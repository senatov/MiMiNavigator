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

    private var manager: RemoteConnectionManager { .shared }
    private var servers: [RemoteServer] { store.servers }


    // MARK: - Body
    var body: some View {
        Menu {
            if servers.isEmpty {
                Text("No servers configured")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(servers) { server in
                    serverMenuRow(server)
                }
            }
            Divider()
            Button {
                ConnectToServerCoordinator.shared.toggle()
            } label: {
                Label("Manage Connections…", systemImage: "slider.horizontal.3")
            }
        } label: {
            dropdownLabel
        }
        .menuStyle(.borderlessButton)
        .frame(width: 130)
        .help("Remote connections")
    }


    // MARK: - Dropdown Label (collapsed state)
    private var dropdownLabel: some View {
        let activeCount = servers.filter { manager.isConnected(to: $0) }.count
        return HStack(spacing: 4) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(activeCount > 0 ? .green : .secondary)
            Text(activeCount > 0 ? "\(activeCount) active" : "Connections")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }


    // MARK: - Server Menu Row
    @ViewBuilder
    private func serverMenuRow(_ server: RemoteServer) -> some View {
        let connected = manager.isConnected(to: server)

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
            serverRowLabel(server: server, connected: true)
        }
    }


    // MARK: - Disconnected Server (single action: connect)
    private func disconnectedServerButton(_ server: RemoteServer) -> some View {
        Button {
            connectServer(server)
        } label: {
            serverRowLabel(server: server, connected: false)
        }
    }


    // MARK: - Shared Row Label
    private func serverRowLabel(server: RemoteServer, connected: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(resolveLampColor(server: server, connected: connected))
                .frame(width: 7, height: 7)
            Text(server.displayName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(resolveNameColor(server: server, connected: connected))
                .lineLimit(1)
            Spacer()
            Text(server.remoteProtocol.rawValue)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
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
            if manager.isConnected(to: server) {
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
    }


    // MARK: - Connect Failure
    private func handleConnectFailure(_ server: RemoteServer) {
        let refreshed = RemoteServerStore.shared.servers.first(where: { $0.id == server.id }) ?? server
        let result = refreshed.lastResult
        let detail = refreshed.lastErrorDetail ?? result.rawValue
        let pp = ProgressPanel.shared
        pp.appendLog("❌ Connection failed: \(result.rawValue)")
        pp.appendLog("Detail: \(detail)")
        if result == .authFailed {
            pp.appendLog("Hint: check username/password or key path")
        } else if result == .timeout {
            pp.appendLog("Hint: host unreachable or firewall blocking port \(server.port)")
        } else if result == .refused {
            pp.appendLog("Hint: \(server.remoteProtocol.rawValue) service not running on \(server.host):\(server.port)")
        }
        pp.finish(success: false, message: "Failed — \(detail)")
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
        guard let remoteURL = URL(string: mountPath) else {
            log.error("[DropdownNav] bad mountPath: \(mountPath)")
            return
        }

        let side = appState.focusedPanel
        appState.updatePath(remoteURL, for: side)
        Task {
            await appState.refreshRemoteFiles(for: side)
        }
        log.info("[DropdownNav] \(side) → \(server.displayName)")
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
            await manager.disconnect(id: conn.id)
            await fallbackPanelsFromServer(server)
            pp.appendLog("Session closed")
            pp.appendLog("Panels restored to local paths")
            pp.finish(success: true, message: "Disconnected from \(server.displayName)")
            log.info("[DropdownDisconnect] \(server.displayName)")
        }
    }


    // MARK: - Fallback all panels showing this server
    private func fallbackPanelsFromServer(_ server: RemoteServer) async {
        let scheme = server.remoteProtocol.urlScheme
        let host = server.host.lowercased()

        for side in FavPanelSide.allCases {
            let panelURL = side == .left ? appState.leftURL : appState.rightURL
            guard isURLMatchingServer(panelURL, scheme: scheme, host: host) else { continue }
            await appState.restoreLocalPath(for: side)
            log.info("[DropdownFallback] \(side) restored from \(server.displayName)")
        }
    }


    // MARK: - URL Matching
    private func isURLMatchingServer(_ url: URL, scheme: String, host: String) -> Bool {
        url.scheme?.lowercased() == scheme && url.host?.lowercased() == host
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


    // MARK: - Name Color
    private func resolveNameColor(server: RemoteServer, connected: Bool) -> Color {
        if connected { return Color(nsColor: .systemGreen) }
        switch server.lastResult {
            case .authFailed, .timeout, .refused, .error:
                return Color(nsColor: .systemRed)
            default:
                return .primary
        }
    }


    // MARK: - Lamp Color
    private func resolveLampColor(server: RemoteServer, connected: Bool) -> Color {
        if connected { return .green }
        switch server.lastResult {
            case .authFailed, .timeout, .refused, .error:
                return Color(nsColor: .systemRed)
            default:
                return Color(nsColor: .systemGray).opacity(0.6)
        }
    }
}
