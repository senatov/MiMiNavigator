// NetworkNeighborhoodView.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: SwiftUI view showing discovered network hosts — used as virtual directory in panel

import SwiftUI

// MARK: - Network Neighborhood panel view
public struct NetworkNeighborhoodView: View {

    @ObservedObject private var provider = NetworkNeighborhoodProvider.shared

    public init() {}

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
        .onAppear { provider.startScan() }
        .onDisappear { provider.stopScan() }
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
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
                    NetworkHostRow(host: host)
                    Divider().padding(.leading, 36)
                }
            }
        }
    }
}

// MARK: - Single host row
struct NetworkHostRow: View {
    let host: NetworkHost
    @State private var isHovered = false

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
        .padding(.vertical, 6)
        .background(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            NetworkNeighborhoodProvider.shared.openInFinder(host)
        }
    }

    private var iconName: String {
        if host.serviceType.contains("smb") { return "externaldrive.connected.to.line.below" }
        if host.serviceType.contains("afp") { return "externaldrive.connected.to.line.below" }
        return "desktopcomputer"
    }
}
