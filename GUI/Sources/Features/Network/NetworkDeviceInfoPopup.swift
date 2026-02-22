// NetworkDeviceInfoPopup.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Refactored: 22.02.2026 — fix RTE: URLSession instead of Process; safe hostName for mobile
// Copyright 2026 Senatov. All rights reserved.
// Description: Device info popup for any network host.

import AppKit
import Foundation
import SwiftUI

// MARK: - MACVendorService
enum MACVendorService {
    // MARK: - lookup
    static func lookup(_ mac: String) async -> String? {
        let prefix = mac.replacingOccurrences(of: ":", with: "").prefix(6).uppercased()
        guard let url = URL(string: "https://api.macvendors.com/" + prefix) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.setValue("MiMiNavigator/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let vendor = String(data: data, encoding: .utf8), !vendor.isEmpty
        else { return nil }
        return vendor
    }
}

// MARK: - DeviceInfoEntry
struct DeviceInfoEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - NetworkDeviceInfoPopup
struct NetworkDeviceInfoPopup: View {
    let host: NetworkHost

    @State private var entries: [DeviceInfoEntry] = []
    @State private var isLoading = true

    // MARK: - body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            popupHeader
            Divider()
            if isLoading {
                ProgressView().padding(20).frame(maxWidth: .infinity)
            } else {
                infoRows
            }
        }
        .frame(width: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .task { await loadInfo() }
    }

    // MARK: - popupHeader
    private var popupHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: host.systemIconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(host.hostDisplayName).font(.headline).lineLimit(1)
                Text(host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    // MARK: - infoRows
    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 6) {
                    Text(entry.label)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .trailing)
                    Text(entry.value)
                        .font(.caption).foregroundStyle(.primary)
                        .textSelection(.enabled)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                Divider().padding(.leading, 102)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - loadInfo
    private func loadInfo() async {
        var result: [DeviceInfoEntry] = []
        let addr = resolvedAddress()

        result.append(DeviceInfoEntry(label: "IP / Host", value: addr))
        if host.name != addr && host.name != host.hostDisplayName {
            result.append(DeviceInfoEntry(label: "Name", value: host.name))
        }
        let typeStr = host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label
        result.append(DeviceInfoEntry(label: "Type", value: typeStr))

        let svcShort = host.bonjourServices
            .map { $0.replacingOccurrences(of: "._tcp.", with: "")
                     .replacingOccurrences(of: "_", with: "") }
            .sorted().joined(separator: ", ")
        if !svcShort.isEmpty {
            result.append(DeviceInfoEntry(label: "Services", value: svcShort))
        }

        if let mac = host.macAddress {
            result.append(DeviceInfoEntry(label: "MAC", value: mac))
            if let vendor = await MACVendorService.lookup(mac) {
                result.append(DeviceInfoEntry(label: "Vendor", value: vendor))
            }
        }

        if host.deviceClass == .printer || host.nodeType == .printer {
            let ippInfo = await probePrinterIPP(address: addr)
            result.append(contentsOf: ippInfo)
        }

        if host.port > 0 {
            result.append(DeviceInfoEntry(label: "Port", value: String(host.port)))
        }

        if host.sharesLoaded && !host.shares.isEmpty {
            let names = host.shares.map { $0.name }.joined(separator: ", ")
            result.append(DeviceInfoEntry(label: "Shares", value: names))
        }

        entries = result
        isLoading = false
    }

    // MARK: - resolvedAddress
    // Returns usable IP/hostname — skips MAC@fe80 Bonjour names
    private func resolvedAddress() -> String {
        let hn = host.hostName
        // MAC-based Bonjour name: "b4:1b:b0:...@fe80::..." — not a real hostname
        if hn.contains("@") || (hn.contains(":") && !hn.contains(".")) {
            return host.hostDisplayName
        }
        if hn.isEmpty || hn == "(nil)" { return host.hostDisplayName }
        return hn
    }

    // MARK: - probePrinterIPP
    // Uses URLSession (async, no blocking) — replaces old Process+waitUntilExit
    private func probePrinterIPP(address: String) async -> [DeviceInfoEntry] {
        guard let url = URL(string: "http://\(address):631/printers") else { return [] }
        let req = URLRequest(url: url, timeoutInterval: 4)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8)
        else { return [] }
        var result: [DeviceInfoEntry] = []
        for (label, tag) in [("Model", "printer-make-and-model"), ("Info", "printer-info")] {
            if let r = html.range(of: tag + "</b>"),
               let end = html[r.upperBound...].range(of: "<") {
                let val = String(html[r.upperBound..<end.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !val.isEmpty { result.append(DeviceInfoEntry(label: label, value: val)) }
            }
        }
        return result
    }

    private var iconColor: Color {
        switch host.deviceClass {
        case .mac:           return .blue
        case .router:        return .orange
        case .printer:       return .purple
        case .nas:           return .green
        case .iPhone, .iPad: return .teal
        case .windowsPC:     return .indigo
        default:             return .secondary
        }
    }
}

// MARK: - NetworkHost helpers
extension NetworkHost {
    // MARK: - nodeTypeLabel
    var nodeTypeLabel: String {
        switch nodeType {
        case .printer:      return "Printer"
        case .mobileDevice: return "Mobile Device"
        case .fileServer:   return "File Server"
        case .generic:      return "Network Device"
        }
    }
}
