// NetworkDeviceInfoLoader.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Loads network device details without coupling probes to popup presentation.

import AppKit
import Foundation
import NetworkKit

// MARK: - Device Info Entry
struct DeviceInfoEntry: Identifiable, Sendable {
    let label: String
    let value: String
    var id: String { "\(label)|\(value)" }
}

// MARK: - Network Device Info Loader
struct NetworkDeviceInfoLoader {
    let host: NetworkHost

    // MARK: - Load
    func load() async -> [DeviceInfoEntry] {
        var result: [DeviceInfoEntry] = []
        appendBaseEntries(&result)
        if let mac = await resolveMACAddress() { await appendMACEntries(&result, mac: mac) }
        if host.deviceClass == .printer || host.nodeType == .printer {
            result.append(contentsOf: await probePrinterIPP())
        }
        appendPortAndShares(&result)
        return result
    }

    private func appendEntry(_ result: inout [DeviceInfoEntry], label: String, value: String) {
        guard !value.isEmpty else { return }
        result.append(DeviceInfoEntry(label: label, value: value))
    }

    private func appendBaseEntries(_ result: inout [DeviceInfoEntry]) {
        if let hostName = safeDisplayedHostName() { appendEntry(&result, label: "Hostname", value: hostName) }
        appendEntry(&result, label: "IP", value: host.hostDisplayName)
        appendEntry(&result, label: "Type", value: resolvedHostType())
        appendEntry(&result, label: "Manufacturer", value: host.manufacturer ?? "")
        appendEntry(&result, label: "Model", value: host.modelName ?? "")
        appendEntry(&result, label: "Services", value: formattedBonjourServices())
        appendEntry(&result, label: "Capabilities", value: host.capabilities.map(\.label).joined(separator: ", "))
    }

    private func safeDisplayedHostName() -> String? {
        let name = host.hostName
        guard !name.isEmpty, name != "(nil)", name != host.name else { return nil }
        return name.contains("@") || (name.contains(":") && !name.contains(".")) ? host.hostDisplayName : name
    }

    private func resolvedHostType() -> String {
        host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label
    }

    private func formattedBonjourServices() -> String {
        host.bonjourServices.map {
            $0.replacingOccurrences(of: "._tcp.", with: "").replacingOccurrences(of: "_", with: "")
        }.sorted().joined(separator: ", ")
    }

    private func resolveMACAddress() async -> String? {
        if let mac = host.macAddress { return mac }
        let ip = host.hostIP.isEmpty ? host.hostName : host.hostIP
        guard !ip.isEmpty, ip != "(nil)", !ip.contains("@") else { return nil }
        return await arpLookup(ip: ip)
    }

    private func appendMACEntries(_ result: inout [DeviceInfoEntry], mac: String) async {
        appendEntry(&result, label: "MAC", value: mac)
        appendEntry(&result, label: "Vendor", value: await MACVendorService.shared.lookup(mac))
    }

    private func appendPortAndShares(_ result: inout [DeviceInfoEntry]) {
        if host.port > 0 { appendEntry(&result, label: "Port", value: String(host.port)) }
        if host.sharesLoaded && !host.shares.isEmpty {
            appendEntry(&result, label: "Shares", value: host.shares.map(\.name).joined(separator: ", "))
        }
    }

    // MARK: - ARP Lookup
    private func arpLookup(ip: String) async -> String? {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4, parts.allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false }) else {
            return await arpLookupByHostname(ip)
        }
        return await runArp(ip)
    }

    private func arpLookupByHostname(_ hostname: String) async -> String? {
        guard !hostname.contains("@"), !hostname.contains(":") else { return nil }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                process.arguments = ["-c", "1", "-t", "1", hostname]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
                process.waitUntilExit()
                continuation.resume()
            }
        }
        return await runArp(hostname)
    }

    private func runArp(_ target: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
                process.arguments = ["-n", target]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                guard (try? process.run()) != nil else { continuation.resume(returning: nil); return }
                process.waitUntilExit()
                guard let data = try? pipe.fileHandleForReading.readToEnd(),
                      let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: nil); return
                }
                let pattern = #"at\s+([0-9a-fA-F:]{17})"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
                      let range = Range(match.range(at: 1), in: output) else {
                    continuation.resume(returning: nil); return
                }
                let mac = String(output[range]).uppercased()
                guard mac != "FF:FF:FF:FF:FF:FF", mac != "00:00:00:00:00:00" else {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: mac)
            }
        }
    }

    // MARK: - Printer Probe
    private func probePrinterIPP() async -> [DeviceInfoEntry] {
        let rawHost = !host.hostName.isEmpty && host.hostName != "(nil)" ? host.hostName : host.hostDisplayName
        let address = rawHost.contains("@") || (rawHost.contains(":") && !rawHost.contains("."))
            ? host.hostDisplayName : rawHost
        guard !address.isEmpty, let url = URL(string: "http://\(address):631/printers"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        let output = String(data: data, encoding: .utf8) ?? ""
        return [("Model", "printer-make-and-model"), ("Info", "printer-info")].compactMap { label, tag in
            extractedPrinterValue(in: output, tag: tag).map { DeviceInfoEntry(label: label, value: $0) }
        }
    }

    private func extractedPrinterValue(in output: String, tag: String) -> String? {
        guard let start = output.range(of: tag + "</b>"),
              let end = output[start.upperBound...].range(of: "<") else { return nil }
        let value = String(output[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
