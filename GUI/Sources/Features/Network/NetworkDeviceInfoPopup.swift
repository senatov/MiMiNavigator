// NetworkDeviceInfoPopup.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright 2026 Senatov. All rights reserved.
// Description: Device info popup for any network host.
//   - MAC vendor lookup via api.macvendors.com (free, no key)
//   - Printer info via IPP (port 631)

import AppKit
import Foundation
import SwiftUI

// MARK: - MACVendorService
actor MACVendorService {
    static let shared = MACVendorService()

    private var cache: [String: String] = [:]
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 1.0  // api.macvendors.com rate limit

    func lookup(_ mac: String) async -> String {
        let prefix = mac.replacingOccurrences(of: ":", with: "").prefix(6).uppercased()

        // Check cache first
        if let cached = cache[prefix] {
            return cached
        }

        // Rate limiting: wait if needed
        if let last = lastRequestTime {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minRequestInterval {
                try? await Task.sleep(nanoseconds: UInt64((minRequestInterval - elapsed) * 1_000_000_000))
            }
        }

        // API request
        guard let url = URL(string: "https://api.macvendors.com/" + prefix) else {
            return "Invalid MAC"
        }

        var req = URLRequest(url: url, timeoutInterval: 3)
        req.setValue("MiMiNavigator/1.0", forHTTPHeaderField: "User-Agent")

        lastRequestTime = Date()

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let httpResp = resp as? HTTPURLResponse

            switch httpResp?.statusCode {
            case 200:
                if let vendor = String(data: data, encoding: .utf8), !vendor.isEmpty {
                    cache[prefix] = vendor
                    return vendor
                }
                return "Unknown"
            case 404:
                cache[prefix] = "Unknown vendor"
                return "Unknown vendor"
            case 429:
                return "Rate limit exceeded"
            default:
                return "API error (\(httpResp?.statusCode ?? 0))"
            }
        } catch {
            return "Network error"
        }
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

    // MARK: - Load device info async (never blocks MainActor)
    private func loadInfo() async {
        var result: [DeviceInfoEntry] = []

        // Hostname
        let displayHN = host.hostName
        if !displayHN.isEmpty && displayHN != "(nil)" && displayHN != host.name {
            // Don't show raw MAC@ip — show resolved IP from hostDisplayName
            let safeHN = (displayHN.contains("@") || (displayHN.contains(":") && !displayHN.contains(".")))
                ? host.hostDisplayName
                : displayHN
            result.append(DeviceInfoEntry(label: "Hostname", value: safeHN))
        }

        // IP address
        result.append(DeviceInfoEntry(label: "IP", value: host.hostDisplayName))

        // Device type
        let typeStr = host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label
        result.append(DeviceInfoEntry(label: "Type", value: typeStr))

        // Services (Bonjour)
        let svcShort = host.bonjourServices
            .map { $0.replacingOccurrences(of: "._tcp.", with: "").replacingOccurrences(of: "_", with: "") }
            .sorted()
            .joined(separator: ", ")
        if !svcShort.isEmpty {
            result.append(DeviceInfoEntry(label: "Services", value: svcShort))
        }

        // MAC + vendor
        // Try stored MAC first, then fallback to ARP lookup by IP
        var mac = host.macAddress
        if mac == nil {
            let ip = host.hostIP.isEmpty ? host.hostName : host.hostIP
            if !ip.isEmpty && ip != "(nil)" && !ip.contains("@") {
                mac = await arpLookup(ip: ip)
            }
        }
        if let mac {
            result.append(DeviceInfoEntry(label: "MAC", value: mac))
            let vendor = await MACVendorService.shared.lookup(mac)
            result.append(DeviceInfoEntry(label: "Vendor", value: vendor))
        }

        // Printer: probe IPP
        if host.deviceClass == .printer || host.nodeType == .printer {
            let ippInfo = await probePrinterIPP(host: host)
            result.append(contentsOf: ippInfo)
        }

        // Port
        if host.port > 0 {
            result.append(DeviceInfoEntry(label: "Port", value: String(host.port)))
        }

        // Shares
        if host.sharesLoaded && !host.shares.isEmpty {
            result.append(DeviceInfoEntry(label: "Shares", value: host.shares.map { $0.name }.joined(separator: ", ")))
        }

        entries = result
        isLoading = false
    }

    // MARK: - ARP lookup: get MAC address from IP via system ARP cache
    private func arpLookup(ip: String) async -> String? {
        // Validate IP format to avoid shell injection
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4, parts.allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false }) else {
            // Not a plain IP — try DNS resolve first
            return await arpLookupByHostname(ip)
        }
        return await runArp(ip)
    }

    private func arpLookupByHostname(_ hostname: String) async -> String? {
        // Resolve hostname to IP, then ARP
        guard !hostname.contains("@"), !hostname.contains(":") else { return nil }
        // Ping once to populate ARP cache (async-safe via GCD)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let pingProc = Process()
                pingProc.executableURL = URL(fileURLWithPath: "/sbin/ping")
                pingProc.arguments = ["-c", "1", "-t", "1", hostname]
                pingProc.standardOutput = FileHandle.nullDevice
                pingProc.standardError = FileHandle.nullDevice
                try? pingProc.run()
                pingProc.waitUntilExit()
                continuation.resume()
            }
        }
        return await runArp(hostname)
    }

    private func runArp(_ target: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
                proc.arguments = ["-n", target]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = FileHandle.nullDevice
                do {
                    try proc.run()
                    proc.waitUntilExit()
                } catch {
                    continuation.resume(returning: nil); return
                }
                guard let data = try? pipe.fileHandleForReading.readToEnd(),
                      let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: nil); return
                }
                // Parse: "? (192.168.x.x) at aa:bb:cc:dd:ee:ff on en0 ..."
                let pattern = #"at\s+([0-9a-fA-F:]{17})"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
                      let range = Range(match.range(at: 1), in: output)
                else {
                    continuation.resume(returning: nil); return
                }
                let mac = String(output[range]).uppercased()
                if mac == "FF:FF:FF:FF:FF:FF" || mac == "00:00:00:00:00:00" {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: mac)
            }
        }
    }

    // MARK: - IPP probe via curl (async — no waitUntilExit on MainActor)
    private func probePrinterIPP(host: NetworkHost) async -> [DeviceInfoEntry] {
        // hostName for mobile = MAC@ip — unusable; fall back to hostDisplayName (IP)
        let rawH = !host.hostName.isEmpty && host.hostName != "(nil)" ? host.hostName : host.hostDisplayName
        let h = (rawH.contains("@") || (rawH.contains(":") && !rawH.contains(".")))
            ? host.hostDisplayName : rawH
        guard !h.isEmpty, let url = URL(string: "http://\(h):631/printers") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        let output = String(data: data, encoding: .utf8) ?? ""
        var result: [DeviceInfoEntry] = []
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
