// RemoteConnectionsPopoverView.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Remote Connections Popover View
struct RemoteConnectionsPopoverView: View {
    let servers: [RemoteServer]
    let isConnected: (RemoteServer) -> Bool
    let onOpen: (RemoteServer) -> Void
    let onConnect: (RemoteServer) -> Void
    let onDisconnect: (RemoteServer) -> Void
    let onManage: () -> Void

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Servers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            if servers.isEmpty {
                Text("No servers configured")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(servers) { server in
                    serverRow(server)
                }
            }
            Divider()
            Button(action: onManage) {
                Label("Manage Connections…", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .padding(8)
        .frame(minWidth: 260)
    }

    // MARK: - Server Row
    private func serverRow(_ server: RemoteServer) -> some View {
        let connected = isConnected(server)
        return HStack(spacing: 5) {
            Image(systemName: "server.rack")
                .foregroundStyle(connected ? Color.green : Color.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)
            Button {
                if connected { onOpen(server) } else { onConnect(server) }
            } label: {
                Text("\(server.displayName) · \(server.remoteProtocol.rawValue)")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(connected ? "Open in active panel" : "Connect")
            Button { onConnect(server) } label: {
                Image(systemName: "link")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(connected)
            .help("Connect to \(server.displayName)")
            .accessibilityLabel("Connect to \(server.displayName)")
            Button { onDisconnect(server) } label: {
                Image(systemName: "xmark.circle")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(!connected)
            .help("Disconnect from \(server.displayName)")
            .accessibilityLabel("Disconnect from \(server.displayName)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
