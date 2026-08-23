// NetworkNeighborhoodView+ShareStatus.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared-folder loading, empty, authentication, and recovery presentation.

import NetworkKit
import SwiftUI

// MARK: - Share Status Presentation
extension NetworkNeighborhoodView {
    var sharesLoadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text("Connecting…").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.leading, 40)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func shareStatusRow(for host: NetworkHost) -> some View {
        HStack(spacing: 8) {
            Image(systemName: statusIconName(for: host))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(shareStatusText(for: host))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if shouldShowSignIn(for: host) {
                Button { authTarget = host } label: {
                    Label("Sign In", systemImage: "key.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                }
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.mini)
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func shouldShowSignIn(for host: NetworkHost) -> Bool {
        guard !host.isLocalhost, !host.deviceClass.isMobile, !host.deviceClass.isRouter else { return false }
        return host.shareLoadState == .authRequired
            || host.shareLoadState == .unavailable
            || host.shareLoadState == .noShares
    }

    private func shareStatusText(for host: NetworkHost) -> String {
        switch host.shareLoadState {
            case .authRequired: return "Authentication required to view shared folders"
            case .unavailable: return "Share list is unavailable right now"
            case .noShares: return host.isLocalhost ? "No shared folders configured" : "No visible shared folders. Try signing in again."
            case .loaded, .idle: return host.isLocalhost ? "No shared folders configured" : "No shares found"
        }
    }

    private func statusIconName(for host: NetworkHost) -> String {
        switch host.shareLoadState {
            case .authRequired: return "lock.fill"
            case .unavailable: return "exclamationmark.triangle.fill"
            case .noShares, .loaded, .idle: return "folder.badge.questionmark"
        }
    }
}
