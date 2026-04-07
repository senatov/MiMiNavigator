//
//  ConnToSrvrView+SideBar.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Sidebar Rows
extension ConnToSrvrView {

    func sidebarServerRow(_ server: RemoteServer) -> some View {
        let isSelected = selectedID == server.id
        let connected = connectionManager.isConnected(to: server)
        let statusColor = sidebarStatusColor(for: server, isSelected: isSelected, connected: connected)

        return HStack(spacing: 8) {
            Image(systemName: Self.iconForProtocol(server.remoteProtocol))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: isSelected ? .light : .regular))
                    .foregroundStyle(isSelected ? .white : Color.primary)
                    .lineLimit(1)

                Text(server.sessionSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedID = server.id
            }
        }
        .contextMenu {
            Button("Connect") {
                connectServerAction(server: server)
            }

            Button("Disconnect") {
                disconnectServerAction(server: server)
            }
            .disabled(!connectionManager.isConnected(to: server) || isConnecting)

            Divider()

            Button("Delete", role: .destructive) {
                deleteServerAction(server: server)
            }
        }
        .padding(.horizontal, 6)
        .glassEffect()
    }

    func sidebarStatusColor(for server: RemoteServer, isSelected: Bool, connected: Bool) -> Color {
        if isSelected { return .white }
        if connected { return .green }

        switch server.lastResult {
            case .authFailed, .timeout, .refused, .error:
                return Color(nsColor: .systemRed)
            default:
                return Color(nsColor: .systemGray).opacity(0.7)
        }
    }
}
