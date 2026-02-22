// NetworkDeviceInfoPopup.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright 2026 Senatov. All rights reserved.
// Description: Device info popup for any network host.
//   - MAC vendor lookup via api.macvendors.com (free, no key)
//   - Printer info via IPP (port 631)
//   - Apple Device name via mDNS TXT record hostname

import AppKit
import Foundation
import SwiftUI

// MARK: - MACVendorService
// Lookup manufacturer by MAC prefix via macvendors.com (free API, no auth)
enum MACVendorService {
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
    @State private var vendor: String?

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

    // MARK: - Header
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

    // MARK: - Info rows
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

    // MARK: - Load device info async
    private func loadInfo() async {
        var result: [DeviceInfoEntry] = []

        // Hostname / IP
        if !host.hostName.isEmpty && host.hostName != "(nil)" && host.hostName != host.name {
            result.append(DeviceInfoEntry(label: "Hostname", value: host.hostName))
        }
        result.append(DeviceInfoEntry(label: "Name", value: host.hostDisplayName))

        // Device type
        let typeStr = host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label
        result.append(DeviceInfoEntry(label: "Type", value: typeStr))

        // Services (Bonjour)
        let svcShort = host.bonjourServices
            .map { $0.replacingOccurrences(of: "._tcp.", with: "").replacingOccurrences(of: "_", with: "") }
            .joined(separator: ", ")
        if !svcShort.isEmpty {
            result.append(DeviceInfoEntry(label: "Services", value: svcShort))
        }

        // MAC + vendor (for Apple mobile devices)
        if let mac = host.macAddress {
            result.append(DeviceInfoEntry(label: "MAC", value: mac))
            let v = await MACVendorService.lookup(mac)
            if let v = v {
                result.append(DeviceInfoEntry(label: "Manufacturer", value: v))
            }
        }

        // Printer: probe IPP for device info
        if host.deviceClass == .printer || host.nodeType == .printer {
            let ippInfo = await probePrinterIPP(host: host)
            result.append(contentsOf: ippInfo)
        }

        // Port
        if host.port > 0 {
            result.append(DeviceInfoEntry(label: "Port", value: String(host.port)))
        }

        // Shares count (if loaded)
        if host.sharesLoaded && !host.shares.isEmpty {
            let names = host.shares.map { $0.name }.joined(separator: ", ")
            result.append(DeviceInfoEntry(label: "Shares", value: names))
        }

        entries = result
        isLoading = false
    }

    // MARK: - IPP probe via curl (port 631)
    private func probePrinterIPP(host: NetworkHost) async -> [DeviceInfoEntry] {
        let h = !host.hostName.isEmpty && host.hostName != "(nil)" ? host.hostName : host.hostDisplayName
        let ippURL = "http://" + h + ":631/printers"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-s", "--max-time", "4", ippURL]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = Pipe()
        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        let data   = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        var result: [DeviceInfoEntry] = []
        // Extract printer-info, printer-make-and-model from HTML
        for (label, tag) in [("Model", "printer-make-and-model"), ("Info", "printer-info")] {
            if let r = output.range(of: tag + "</b>"),
               let end = output[r.upperBound...].range(of: "<") {
                let val = String(output[r.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { result.append(DeviceInfoEntry(label: label, value: val)) }
            }
        }
        return result
    }

    private var iconColor: Color {
        switch host.deviceClass {
        case .mac:      return .blue
        case .router:   return .orange
        case .printer:  return .purple
        case .nas:      return .green
        case .iPhone, .iPad: return .green
        default:        return .secondary
        }
    }
}

// MARK: - NetworkNodeType label helper
extension NetworkHost {
    var nodeTypeLabel: String {
        switch nodeType {
        case .printer:      return "Printer"
        case .mobileDevice: return "Mobile Device"
        case .fileServer:   return "File Server"
        case .generic:      return "Network Device"
        }
    }
}