// NetworkNeighborhoodView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Tree-style Network Neighborhood — Bonjour + FritzBox TR-064 discovery.
//   - NSPanel via NetworkNeighborhoodCoordinator (movable, resizable, persists position)
//   - Web UI button for ANY device with responding HTTP port (23 ports probed)
//   - mediaBox (Enigma2/OpenPLi/Kodi): icon=tv/red, no SMB expand, no Sign In
//   - Right-click context menu: copy name / IP / Web URL / MAC / mount URL
//   - Offline hosts hidden; Sign In only for expandable non-mobile non-router hosts

import SwiftUI

// MARK: - Network Neighborhood View
struct NetworkNeighborhoodView: View {

    @ObservedObject private var provider = NetworkNeighborhoodProvider.shared
    var onNavigate: ((URL) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var expanded: Set<NetworkHost.ID> = []
    @State private var authTarget: NetworkHost? = nil

    // MARK: - Only online hosts
    private var visibleHosts: [NetworkHost] {
        provider.hosts.filter { !$0.isOffline }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if visibleHosts.isEmpty && !provider.isScanning {
                emptyState
            } else {
                hostTree
            }
        }
        .frame(minWidth: 380, idealWidth: 460, minHeight: 280)
        .background(DialogColors.base)
        .onAppear {
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
                Button {
                    provider.startDiscovery()
                } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
                .buttonStyle(.plain).help("Rescan (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
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
                ForEach(visibleHosts) { host in
                    hostRow(host)
                    Divider().padding(.leading, 36)
                    if expanded.contains(host.id) {
                        sharesSection(for: host)
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

    // MARK: - Shares section below host
    @ViewBuilder
    private func sharesSection(for host: NetworkHost) -> some View {
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

    // MARK: - Single host row
    @ViewBuilder
    private func hostRow(_ host: NetworkHost) -> some View {
        HostNodeRow(
            host: host,
            isExpanded: expanded.contains(host.id),
            onToggle: { toggle(host) },
            onOpenWebUI: {
                if let url = host.webUIURL { NSWorkspace.shared.open(url) }
            }
        )
        .contextMenu {
            hostContextMenu(host)
        }
    }

    // MARK: - Context menu: copy name / IP / URL (for keyboard warriors and power users)
    @ViewBuilder
    private func hostContextMenu(_ host: NetworkHost) -> some View {
        Button {
            copy(host.hostDisplayName)
        } label: {
            Label("Copy Name: \"\(host.hostDisplayName)\"", systemImage: "doc.on.doc")
        }

        let ip = resolvedIP(host)
        if !ip.isEmpty {
            Button { copy(ip) } label: {
                Label("Copy IP: \(ip)", systemImage: "number")
            }
        }

        if let url = host.webUIURL {
            Button { copy(url.absoluteString) } label: {
                Label("Copy Web URL: \(url.absoluteString)", systemImage: "link")
            }
            Divider()
            Button { NSWorkspace.shared.open(url) } label: {
                Label("Open Web UI", systemImage: "safari")
            }
        }

        if let mountURL = host.mountURL {
            Button { copy(mountURL.absoluteString) } label: {
                Label("Copy Mount URL", systemImage: "externaldrive")
            }
        }

        if let mac = host.macAddress {
            Divider()
            Button { copy(mac) } label: {
                Label("Copy MAC: \(mac)", systemImage: "antenna.radiowaves.left.and.right")
            }
        }

        Divider()
        Button {
            let lines = buildCopyText(host)
            copy(lines)
        } label: {
            Label("Copy All Info", systemImage: "doc.on.clipboard")
        }
    }

    // MARK: - Build multi-line copy text for "Copy All Info"
    private func buildCopyText(_ host: NetworkHost) -> String {
        var lines = ["Name: \(host.hostDisplayName)"]
        let ip = resolvedIP(host)
        if !ip.isEmpty { lines.append("IP: \(ip)") }
        if let mac = host.macAddress { lines.append("MAC: \(mac)") }
        if !host.deviceClass.label.isEmpty { lines.append("Type: \(host.deviceClass.label)") }
        if let url = host.webUIURL { lines.append("Web UI: \(url.absoluteString)") }
        if let url = host.mountURL { lines.append("Mount: \(url.absoluteString)") }
        if !host.bonjourServices.isEmpty {
            let svcs = host.bonjourServices.sorted().joined(separator: ", ")
            lines.append("Services: \(svcs)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Copy to clipboard
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Best IP for display / copy
    private func resolvedIP(_ host: NetworkHost) -> String {
        if !host.hostIP.isEmpty { return host.hostIP }
        let hn = host.hostName
        if !hn.isEmpty && hn != "(nil)" && !hn.contains("@") { return hn }
        return ""
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

    // MARK: - No shares row
    private func noSharesRow(for host: NetworkHost) -> some View {
        HStack(spacing: 8) {
            Text("😞").font(.system(size: 14))
            Text(host.isLocalhost ? "No shared folders configured" : "No shares found")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            if !host.isLocalhost && !host.deviceClass.isMobile && !host.deviceClass.isRouter
                && host.deviceClass != .mediaBox {
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
    @State private var showInfoPopup = false

    // Port is being probed — show spinner on Web UI area
    private var isProbing: Bool {
        host.probedWebURL == nil && host.staticWebUIURL == nil
            && !host.isOffline && host.deviceClass != .iPhone && host.deviceClass != .iPad
    }

    var body: some View {
        HStack(spacing: 0) {
            chevron
            deviceIcon
            nameStack
            Spacer()
            actionButtons
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

    // MARK: - Chevron
    private var chevron: some View {
        Group {
            if host.isExpandable {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    .frame(width: 20).contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { onToggle() } }
            } else {
                Spacer().frame(width: 20)
            }
        }
    }

    // MARK: - Device icon
    private var deviceIcon: some View {
        Image(systemName: host.systemIconName)
            .font(.system(size: 16))
            .foregroundStyle(iconColor)
            .frame(width: 24)
    }

    // MARK: - Name + IP sub-label
    private var nameStack: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(host.hostDisplayName)
                .font(.callout).lineLimit(1)
            // Show IP on second line when available
            let ip = resolvedIP
            if !ip.isEmpty {
                Text(ip).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.leading, 6)
    }

    // MARK: - Right-side action buttons
    private var actionButtons: some View {
        HStack(spacing: 4) {
            // Web UI button — shown when URL known (static or probed)
            if let url = host.webUIURL {
                Button { onOpenWebUI() } label: {
                    Label("Web UI", systemImage: "safari")
                        .font(.caption2)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
                .tint(webUIColor)
                .controlSize(.mini)
            }
            // Device badge when no Web UI button yet
            if host.webUIURL == nil && !host.deviceLabel.isEmpty {
                Text(host.deviceLabel)
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            // Info button — hover only
            if isHovered {
                Button { showInfoPopup.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13)).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Device info")
                .popover(isPresented: $showInfoPopup, arrowEdge: .trailing) {
                    NetworkDeviceInfoPopup(host: host)
                }
            }
        }
        .padding(.trailing, 6)
    }

    // MARK: - Resolved IP for display
    private var resolvedIP: String {
        if !host.hostIP.isEmpty { return host.hostIP }
        let hn = host.hostName
        if !hn.isEmpty && hn != "(nil)" && !hn.contains("@") && !hn.contains(":") { return hn }
        return ""
    }

    // MARK: - Web UI button color
    private var webUIColor: Color {
        switch host.deviceClass {
        case .printer: return .purple
        case .router:  return .orange
        case .nas:     return .teal
        default:       return .blue
        }
    }

    // MARK: - Icon color
    private var iconColor: Color {
        switch host.deviceClass {
        case .router:        return .orange
        case .iPhone, .iPad: return .green
        case .printer:       return .purple
        case .nas:           return .mint
        case .mac:           return .blue
        case .windowsPC:     return .indigo
        case .linuxServer:   return .cyan
        case .mediaBox:      return .red
        default:             return host.nodeType == .printer ? .purple : .secondary
        }
    }
}

// MARK: - Share row
private struct ShareRow: View {
    let share: NetworkShare
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill.badge.person.crop")
                .font(.system(size: 13))
                .foregroundStyle(.blue.opacity(0.7))
                .frame(width: 20)
            Text(share.name)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.leading, 44).padding(.trailing, 10).padding(.vertical, 5)
        .background(isHovered ? Color.accentColor.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(share.name, forType: .string)
            } label: {
                Label("Copy Share Name", systemImage: "doc.on.doc")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(share.url.absoluteString, forType: .string)
            } label: {
                Label("Copy Mount URL", systemImage: "link")
            }
        }
    }
}
