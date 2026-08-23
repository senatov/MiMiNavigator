// NetworkNeighborhoodView+ContextMenu.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Device copy and Web UI actions for Network Neighborhood.

import AppKit
import NetworkKit
import SwiftUI

// MARK: - Host Context Menu
extension NetworkNeighborhoodView {
    @ViewBuilder
    func hostContextMenu(_ host: NetworkHost) -> some View {
        Button { copyHostText(host.hostDisplayName) } label: {
            Label("Copy Name: \"\(host.hostDisplayName)\"", systemImage: "doc.on.doc")
        }
        let ip = resolvedIP(host)
        if !ip.isEmpty {
            Button { copyHostText(ip) } label: {
                Label("Copy IP: \(ip)", systemImage: "number")
            }
        }
        if let url = host.webUIURL {
            Button { copyHostText(url.absoluteString) } label: {
                Label("Copy Web URL: \(url.absoluteString)", systemImage: "link")
            }
            Divider()
            Button { NSWorkspace.shared.open(url) } label: {
                Label("Open Web UI", systemImage: "safari")
            }
        }
        if let mountURL = host.mountURL {
            Button { copyHostText(mountURL.absoluteString) } label: {
                Label("Copy Mount URL", systemImage: "externaldrive")
            }
        }
        if let mac = host.macAddress {
            Divider()
            Button { copyHostText(mac) } label: {
                Label("Copy MAC: \(mac)", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
        Divider()
        Button { copyHostText(buildCopyText(host)) } label: {
            Label("Copy All Info", systemImage: "doc.on.clipboard")
        }
    }

    private func buildCopyText(_ host: NetworkHost) -> String {
        var lines = ["Name: \(host.hostDisplayName)"]
        let ip = resolvedIP(host)
        if !ip.isEmpty { lines.append("IP: \(ip)") }
        if let mac = host.macAddress { lines.append("MAC: \(mac)") }
        if !host.deviceClass.label.isEmpty { lines.append("Type: \(host.deviceClass.label)") }
        if let url = host.webUIURL { lines.append("Web UI: \(url.absoluteString)") }
        if let url = host.mountURL { lines.append("Mount: \(url.absoluteString)") }
        if !host.bonjourServices.isEmpty {
            lines.append("Services: \(host.bonjourServices.sorted().joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private func copyHostText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func resolvedIP(_ host: NetworkHost) -> String {
        if !host.hostIP.isEmpty { return host.hostIP }
        let hostName = host.hostName
        if !hostName.isEmpty && hostName != "(nil)" && !hostName.contains("@") { return hostName }
        return ""
    }
}
