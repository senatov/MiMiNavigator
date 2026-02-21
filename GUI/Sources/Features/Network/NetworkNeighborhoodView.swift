// NetworkNeighborhoodView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Tree-style Network Neighborhood window.
//   - Hosts are top-level nodes (fileServer / printer / generic)
//   - Click ▶ on a fileServer → expands inline, fetches shares
//   - Click a share → navigates active panel directly (no Finder)
//   - Printers show icon only, no expand

import SwiftUI

// MARK: - Network Neighborhood Window Content
struct NetworkNeighborhoodView: View {

    @ObservedObject private var provider = NetworkNeighborhoodProvider.shared
    /// Called when user selects a share URL — navigate active panel there
    var onNavigate: ((URL) -> Void)?
    /// Called when user closes
    var onDismiss: (() -> Void)?

    // Tracks which host nodes are expanded
    @State private var expanded: Set<NetworkHost.ID> = []

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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { provider.startDiscovery() }
        .onDisappear { provider.stopDiscovery() }
        .onKeyPress(.escape) { onDismiss?(); return .handled }
    }

    // MARK: - Header bar
    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "network")
                .foregroundStyle(.secondary)
            Text("Network Neighborhood")
                .font(.subheadline.weight(.medium))
            Spacer()
            if provider.isScanning {
                ProgressView().scaleEffect(0.6)
            } else {
                Button { provider.startDiscovery() } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
                .buttonStyle(.plain)
                .help("Rescan network")
            }
            Button { onDismiss?() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: provider.isScanning ? "network" : "network.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, isActive: provider.isScanning)
            Text(provider.isScanning ? "Scanning…" : "No hosts found")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tree: host rows + share rows + scanning footer
    private var hostTree: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(provider.hosts) { host in
                    HostNodeRow(
                        host: host,
                        isExpanded: expanded.contains(host.id),
                        onToggle: { toggle(host) }
                    )
                    Divider().padding(.leading, 36)

                    if expanded.contains(host.id) {
                        if host.sharesLoading {
                            sharesLoadingRow
                        } else if host.sharesLoaded && host.shares.isEmpty {
                            noSharesRow
                        } else {
                            ForEach(host.shares) { share in
                                ShareRow(share: share) { onNavigate?(share.url) }
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }

                // Scanning footer — visible while discovery is running
                if provider.isScanning {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.65)
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Loading spinner row
    private var sharesLoadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text("Loading shares…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 40)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - No shares row
    private var noSharesRow: some View {
        Text("No accessible shares")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.leading, 40)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toggle expand/collapse
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

// MARK: - Host node row (top level)
private struct HostNodeRow: View {
    let host: NetworkHost
    let isExpanded: Bool
    let onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Expand/collapse chevron — only for file servers
            if host.isExpandable {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { onToggle() } }
            } else {
                // Placeholder to keep alignment
                Spacer().frame(width: 20)
            }

            // Host icon
            Image(systemName: host.systemIconName)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)

            // Name + IP
            VStack(alignment: .leading, spacing: 1) {
                Text(host.name)
                    .font(.callout)
                    .lineLimit(1)
                if let ip = firstIP(host) {
                    Text(ip)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 6)

            Spacer()

            // Printer badge
            if host.nodeType == .printer {
                Text("Printer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        // Tap on the row itself also toggles (if expandable)
        .onTapGesture {
            guard host.isExpandable else { return }
            withAnimation(.easeInOut(duration: 0.15)) { onToggle() }
        }
    }

    private func firstIP(_ host: NetworkHost) -> String? {
        // hostName may be "macbook.local" — show as-is; it's more useful than UUID-based name
        return host.hostName.isEmpty ? nil : host.hostName
    }
}

// MARK: - Share row (second level)
private struct ShareRow: View {
    let share: NetworkShare
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // Indent
            Spacer().frame(width: 36)

            Image(systemName: "folder.connected.to.link")
                .font(.system(size: 13))
                .foregroundStyle(.blue.opacity(0.8))
                .frame(width: 18)

            Text(share.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Image(systemName: "arrow.right.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}
