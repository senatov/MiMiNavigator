// NetworkNeighborhoodView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Refactored: 21.02.2026 — router Web UI button inline; FritzBox/PC/NAS device badges
// Refactored: 22.02.2026 — layout recursion fix: defer startDiscovery via Task
// Refactored: 22.02.2026 — no Sign In for localhost/mobile; mobile icon color; localhost badge
// Copyright © 2026 Senatov. All rights reserved.
// Description: Tree-style Network Neighborhood — Bonjour + FritzBox TR-064 discovery.

import SwiftUI

// MARK: - Network Neighborhood Window
struct NetworkNeighborhoodView: View {

    @ObservedObject private var provider = NetworkNeighborhoodProvider.shared
    var onNavigate: ((URL) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var expanded: Set<NetworkHost.ID> = []
    @State private var authTarget: NetworkHost? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if provider.hosts.isEmpty && !provider.isScanning {
                emptyState
            } else {
                hostTree
            }
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 280)
        .background(DialogColors.base)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            // Defer startDiscovery to next runloop tick to avoid layout recursion warning
            Task { @MainActor in provider.startDiscovery() }
        }
        .onDisappear { provider.stopDiscovery() }
        .onKeyPress(.escape) { onDismiss?(); return .handled }
        .sheet(item: $authTarget) { host in
            NetworkAuthSheet(host: host) {
                authTarget = nil
                Task { await provider.retryFetchShares(for: host.id) }
            } onCancel: { authTarget = nil }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "network").foregroundStyle(.secondary)
            Text("Network Neighborhood").font(.subheadline.weight(.medium))
            Spacer()
            if provider.isScanning {
                ProgressView().scaleEffect(0.6)
            } else {
                Button { provider.startDiscovery() } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
                .buttonStyle(.plain).help("Rescan")
            }
            Button { onDismiss?() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Close (Esc)")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DialogColors.stripe)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: provider.isScanning ? "network" : "network.slash")
                .font(.largeTitle).foregroundStyle(.tertiary)
                .symbolEffect(.pulse, isActive: provider.isScanning)
            Text(provider.isScanning ? "Scanning…" : "No hosts found")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Host tree
    private var hostTree: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(provider.hosts) { host in
                    hostRow(host)
                    Divider().padding(.leading, 36)

                    if expanded.contains(host.id) {
                        if host.sharesLoading {
                            sharesLoadingRow
                        } else if host.sharesLoaded && host.shares.isEmpty {
                            noSharesRow(for: host)
                        } else {
                            ForEach(host.shares) { share in
                                ShareRow(share: share) { onNavigate?(share.url) }
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }
                if provider.isScanning {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.65)
                        Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Single host row
    @ViewBuilder
    private func hostRow(_ host: NetworkHost) -> some View {
        HostNodeRow(
            host: host,
            isExpanded: expanded.contains(host.id),
            onToggle: { toggle(host) },
            onOpenWebUI: {
                if let url = URL(string: "http://\(host.hostName)") {
                    NSWorkspace.shared.open(url)
                }
            }
        )
    }

    // MARK: - Loading row
    private var sharesLoadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text("Connecting…").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.leading, 40).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - No shares / access denied row
    private func noSharesRow(for host: NetworkHost) -> some View {
        HStack(spacing: 8) {
            Text("😞").font(.system(size: 14))
            Text(host.isLocalhost ? "No shared folders configured" : "No shares found")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            // No Sign In button for: localhost (this Mac), mobile devices, routers
            if !host.isLocalhost && !host.deviceClass.isMobile && !host.deviceClass.isRouter {
                Button { authTarget = host } label: {
                    Label("Sign In", systemImage: "key.fill")
                        .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent).controlSize(.mini)
            }
        }
        .padding(.leading, 40).padding(.trailing, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Expand toggle
    private func toggle(_ host: NetworkHost) {
        guard host.isExpandable else { return }
        if expanded.contains(host.id) {
            expanded.remove(host.id)
        } else {
            expanded.insert(host.id)
            Task { await provider.fetchShares(for: host.id) }
        }
    }
}

// MARK: - Host node row
private struct HostNodeRow: View {
    let host: NetworkHost
    let isExpanded: Bool
    let onToggle: () -> Void
    let onOpenWebUI: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Chevron or spacer
            if host.isExpandable {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    .frame(width: 20).contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { onToggle() } }
            } else {
                Spacer().frame(width: 20)
            }

            // Icon
            Image(systemName: host.systemIconName)
                .font(.system(size: 16))
                .foregroundStyle(
                    host.deviceClass == .router  ? Color.orange :
                    host.deviceClass == .iPhone  ? Color.green :
                    host.deviceClass == .iPad    ? Color.green :
                    host.nodeType    == .printer ? Color.secondary : Color.blue
                )
                .frame(width: 24)

            // Name + sub-label
            VStack(alignment: .leading, spacing: 1) {
                Text(host.name).font(.callout).lineLimit(1)
                Text(host.hostName).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.leading, 6)

            Spacer()

            // Right side: badge OR router button
            if host.deviceClass == .router {
                Button {
                    onOpenWebUI()
                } label: {
                    Label("Web UI", systemImage: "safari")
                        .font(.caption2)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.mini)
                .padding(.trailing, 6)
            } else if !host.deviceLabel.isEmpty {
                Text(host.isLocalhost ? "This Mac" : host.deviceLabel)
                    .font(.caption2)
                    .foregroundStyle(host.isLocalhost ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((host.isLocalhost ? Color.accentColor : Color.secondary).opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.trailing, 6)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            guard host.isExpandable else { return }
            withAnimation(.easeInOut(duration: 0.15)) { onToggle() }
        }
    }
}

// MARK: - Share row
private struct ShareRow: View {
    let share: NetworkShare
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Spacer().frame(width: 36)
            Image(systemName: "folder.connected.to.link")
                .font(.system(size: 13)).foregroundStyle(.blue.opacity(0.8)).frame(width: 18)
            Text(share.name).font(.callout).lineLimit(1).truncationMode(.middle)
            Spacer()
            Image(systemName: "arrow.right.circle").font(.caption).foregroundStyle(.tertiary).padding(.trailing, 4)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}
