// NetworkNeighborhoodView.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: SwiftUI view showing discovered network hosts with navigation callback

import SwiftUI

// MARK: - Network Neighborhood panel view
public struct NetworkNeighborhoodView: View {

    @ObservedObject private var provider = NetworkNeighborhoodProvider.shared
    /// Called when user double-clicks a host — navigate focused panel to smb:// URL
    public var onNavigate: ((URL) -> Void)?
    /// Called when user closes the sheet
    public var onDismiss: (() -> Void)?

    public init(onNavigate: ((URL) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.onNavigate = onNavigate
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if provider.hosts.isEmpty {
                emptyState
            } else {
                hostList
            }
        }
        .frame(minWidth: 360, minHeight: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { provider.startScan() }
        .onDisappear { provider.stopScan() }
        .onKeyPress(.escape) {
            onDismiss?()
            return .handled
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Image(systemName: "network")
                .foregroundStyle(.secondary)
            Text("Network Neighborhood")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            if provider.isScanning {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(.trailing, 4)
            } else {
                Button {
                    provider.startScan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .help("Rescan network")
            }
            // Close button
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "network.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(provider.isScanning ? "Scanning…" : "No hosts found")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Host list
    private var hostList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(provider.hosts) { host in
                    NetworkHostRow(host: host, onNavigate: onNavigate)
                    Divider().padding(.leading, 36)
                }
            }
        }
    }
}

// MARK: - Single host row
struct NetworkHostRow: View {
    let host: NetworkHost
    var onNavigate: ((URL) -> Void)?
    @State private var isHovered = false
    @State private var isSelected = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .frame(width: 20)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(host.name)
                    .font(.callout)
                if let ip = host.addresses.first {
                    Text(ip)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.20)
                : (isHovered ? Color.accentColor.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            isSelected = true
        }
        .onTapGesture(count: 2) {
            guard let url = host.smbURL ?? host.afpURL else { return }
            if let navigate = onNavigate {
                // Navigate panel directly
                navigate(url)
            } else {
                // Fallback: open in Finder
                NetworkNeighborhoodProvider.shared.openInFinder(host)
            }
        }
    }

    private var iconName: String {
        switch true {
        case host.serviceType.contains("smb"):  return "externaldrive.connected.to.line.below"
        case host.serviceType.contains("afp"):  return "externaldrive.connected.to.line.below"
        case host.serviceType.contains("ssh"),
             host.serviceType.contains("sftp"): return "terminal"
        case host.serviceType.contains("http"): return "globe"
        default:                                return "desktopcomputer"
        }
    }
}
