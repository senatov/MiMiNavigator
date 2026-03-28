// HostNodeRow.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single host row in Network Neighborhood tree.
//   Extracted from NetworkNeighborhoodView.swift for single responsibility.

import SwiftUI


// MARK: - Host node row

struct HostNodeRow: View {
    let host: NetworkHost
    let isExpanded: Bool
    let onToggle: () -> Void
    let onOpenWebUI: () -> Void

    @State private var isHovered = false
    @State private var showInfoPopup = false

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
            if host.webUIURL != nil {
                Button { onOpenWebUI() } label: {
                    Label("Web UI", systemImage: "safari")
                        .font(.caption2)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                }
                .buttonStyle(ThemedButtonStyle())
                .tint(webUIColor)
                .controlSize(.mini)
            }
            if host.webUIURL == nil && !host.deviceLabel.isEmpty {
                Text(host.deviceLabel)
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            if isHovered {
                Button { showInfoPopup.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14)).foregroundStyle(.blue)
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



    // MARK: - Helpers

    private var resolvedIP: String {
        if !host.hostIP.isEmpty { return host.hostIP }
        let hn = host.hostName
        if !hn.isEmpty && hn != "(nil)" && !hn.contains("@") && !hn.contains(":") { return hn }
        return ""
    }

    private var webUIColor: Color {
        switch host.deviceClass {
        case .printer: return .purple
        case .router:  return .orange
        case .nas:     return .teal
        default:       return .blue
        }
    }

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
