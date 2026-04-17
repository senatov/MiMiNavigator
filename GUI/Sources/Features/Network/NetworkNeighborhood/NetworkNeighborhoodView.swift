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

    private enum Layout {
        static let minWidth: CGFloat = 380
        static let idealWidth: CGFloat = 460
        static let minHeight: CGFloat = 280
        static let outerCornerRadius: CGFloat = 14
        static let sectionCornerRadius: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let compactHorizontalPadding: CGFloat = 10
        static let rowDividerInset: CGFloat = 36
        static let shareDividerInset: CGFloat = 56
        static let sectionHeaderHorizontalPadding: CGFloat = 12
        static let sectionHeaderTopPadding: CGFloat = 10
        static let sectionHeaderBottomPadding: CGFloat = 4
    }


    private enum HostSection: Int, CaseIterable {
        case infrastructure
        case computersAndStorage
        case mobileAndMedia
        case other

        var title: String {
            switch self {
                case .infrastructure:
                    return "Infrastructure"
                case .computersAndStorage:
                    return "Computers & Storage"
                case .mobileAndMedia:
                    return "Mobile & Media"
                case .other:
                    return "Other"
            }
        }
    }

    // MARK: - Only online hosts
    private var visibleHosts: [NetworkHost] {
        sortedHosts(provider.hosts.filter { !$0.isOffline })
    }

    private var shouldShowEmptyState: Bool {
        visibleHosts.isEmpty && !provider.isScanning
    }

    private var hostCountText: String {
        let count = visibleHosts.count
        return count == 1 ? "1 host" : "\(count) hosts"
    }

    private var groupedHosts: [(section: HostSection, hosts: [NetworkHost])] {
        var buckets: [HostSection: [NetworkHost]] = [:]

        for host in visibleHosts {
            buckets[sectionForHost(host), default: []].append(host)
        }

        return HostSection.allCases.compactMap { section in
            guard let hosts = buckets[section], !hosts.isEmpty else { return nil }
            return (section, hosts)
        }
    }
    private var scanningStatusText: String {
        provider.isScanning ? "Scanning network…" : hostCountText
    }


    // MARK: - Glass Styling
    // MARK: - Host Organization
    private func sectionForHost(_ host: NetworkHost) -> HostSection {
        if host.deviceClass.isInfrastructure {
            return .infrastructure
        }
        if host.deviceClass.isComputer || host.deviceClass.isStorage {
            return .computersAndStorage
        }
        if host.deviceClass.isMobile || host.deviceClass.isMediaDevice || host.deviceClass.isIoT {
            return .mobileAndMedia
        }
        return .other
    }

    private func sortRank(for host: NetworkHost) -> Int {
        let device = host.deviceClass
        if device.isInfrastructure { return 0 }
        if device.isComputer { return 1 }
        if device.isStorage { return 2 }
        if device.isMobile { return 3 }
        if device.isMediaDevice { return 4 }
        if device.isIoT { return 5 }
        return 6
    }

    private func sortedHosts(_ hosts: [NetworkHost]) -> [NetworkHost] {
        hosts.sorted { lhs, rhs in
            let lhsRank = sortRank(for: lhs)
            let rhsRank = sortRank(for: rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            let lhsName = lhs.hostDisplayName.lowercased()
            let rhsName = rhs.hostDisplayName.lowercased()
            if lhsName != rhsName {
                return lhsName < rhsName
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // MARK: - Glass Styling
    @ViewBuilder
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .fill(.clear)
    }

    @ViewBuilder
    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    @ViewBuilder
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
    }

    @ViewBuilder
    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
    }

    @ViewBuilder
    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    var body: some View {
        VStack(spacing: 10) {
            headerBar

            if shouldShowEmptyState {
                emptyState
            } else {
                hostTree
            }
        }
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.idealWidth, minHeight: Layout.minHeight)
        .padding(.top, 10)
        .background(panelBackground)
        .glassEffect(.regular)
        .overlay(panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
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

    // MARK: - Header (action bar only — title is in titlebar accessory)
    private var headerBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Network Neighborhood")
                    .font(.headline)
                Text(scanningStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if provider.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(hostCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    provider.startDiscovery()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .padding(6)
                        .background {
                            Circle()
                                .fill(.quaternary.opacity(0.9))
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(.quaternary, lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .help("Rescan (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, 8)
        .background(headerBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHorizontalPadding)
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
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHorizontalPadding)
        .padding(.bottom, 10)
    }

    // MARK: - Host tree
    private var hostTree: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupedHosts, id: \.section) { group in
                    sectionHeader(group.section.title)

                    ForEach(Array(group.hosts.enumerated()), id: \.element.id) { index, host in
                        hostRow(host)
                        if expanded.contains(host.id) {
                            sharesSection(for: host)
                        }
                        if index < group.hosts.count - 1 {
                            Divider().padding(.leading, Layout.rowDividerInset)
                        }
                    }
                }

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
            .padding(.vertical, 4)
        }
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHorizontalPadding)
        .padding(.bottom, 10)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.8)
        }
        .padding(.horizontal, Layout.sectionHeaderHorizontalPadding)
        .padding(.top, Layout.sectionHeaderTopPadding)
        .padding(.bottom, Layout.sectionHeaderBottomPadding)
    }

    // MARK: - Shares section below host
    @ViewBuilder
    private func sharesSection(for host: NetworkHost) -> some View {
        if host.sharesLoading {
            sharesLoadingRow
        } else if host.sharesLoaded && host.shares.isEmpty {
            shareStatusRow(for: host)
        } else {
            ForEach(Array(host.shares.enumerated()), id: \.element.id) { index, share in
                ShareRow(share: share) {
                    onNavigate?(NetworkAuthService.authenticatedURL(for: share.url))
                }
                if index < host.shares.count - 1 {
                    Divider().padding(.leading, Layout.shareDividerInset)
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
        .padding(.leading, 40)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Share status row
    private func shareStatusRow(for host: NetworkHost) -> some View {
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
                        .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                }
                .buttonStyle(ThemedButtonStyle()).controlSize(.mini)
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shareStatusText(for host: NetworkHost) -> String {
        switch host.shareLoadState {
        case .authRequired:
            return "Authentication required to view shared folders"
        case .unavailable:
            return "Share list is unavailable right now"
        case .noShares:
            return host.isLocalhost ? "No shared folders configured" : "No visible shared folders. Try signing in again."
        case .loaded, .idle:
            return host.isLocalhost ? "No shared folders configured" : "No shares found"
        }
    }

    private func statusIconName(for host: NetworkHost) -> String {
        switch host.shareLoadState {
        case .authRequired:
            return "lock.fill"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        case .noShares, .loaded, .idle:
            return "folder.badge.questionmark"
        }
    }

    private func shouldShowSignIn(for host: NetworkHost) -> Bool {
        guard !host.isLocalhost,
              !host.deviceClass.isMobile,
              !host.deviceClass.isRouter,
              host.deviceClass != .mediaBox
        else {
            return false
        }

        return host.shareLoadState == .authRequired
            || host.shareLoadState == .unavailable
            || host.shareLoadState == .noShares
    }

    private func shouldAutoPromptForAuthentication(for host: NetworkHost) -> Bool {
        guard shouldShowSignIn(for: host), authTarget == nil else { return false }

        switch host.shareLoadState {
        case .authRequired, .noShares:
            return true
        case .idle, .loaded, .unavailable:
            return false
        }
    }

    private func expandHost(_ host: NetworkHost) {
        expanded.insert(host.id)
        Task {
            await provider.fetchShares(for: host.id)

            guard let refreshedHost = provider.hosts.first(where: { $0.id == host.id }) else { return }
            guard shouldAutoPromptForAuthentication(for: refreshedHost) else { return }

            log.info("[Network] opening auth sheet after share lookup for '\(refreshedHost.name)' state=\(refreshedHost.shareLoadState.rawValue)")
            authTarget = refreshedHost
        }
    }

    // MARK: - Expand toggle
    private func toggle(_ host: NetworkHost) {
        guard host.isExpandable else { return }

        if expanded.contains(host.id) {
            expanded.remove(host.id)
            return
        }

        expandHost(host)
    }
}
