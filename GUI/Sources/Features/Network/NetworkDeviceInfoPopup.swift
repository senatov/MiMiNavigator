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

// MARK: - DeviceInfoEntry
struct DeviceInfoEntry: Identifiable {
    let label: String
    let value: String

    var id: String {
        "\(label)|\(value)"
    }
}

// MARK: - NetworkDeviceInfoPopup
struct NetworkDeviceInfoPopup: View {
    let host: NetworkHost

    @State private var entries: [DeviceInfoEntry] = []
    @State private var isLoading = true

    private enum Layout {
        static let popupWidth: CGFloat = 340
        static let cornerRadius: CGFloat = 14
        static let sectionCornerRadius: CGFloat = 12
        static let headerHPadding: CGFloat = 12
        static let rowHPadding: CGFloat = 12
        static let labelWidth: CGFloat = 90
        static let dividerInset: CGFloat = 102
    }

    private enum Glass {
        static let borderOpacity: Double = 0.14
        static let sectionTintOpacity: Double = 0.07
        static let headerTintOpacity: Double = 0.09
    }

    // MARK: - Glass Styling
    @ViewBuilder
    private var popupBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.sectionTintOpacity)))
    }

    @ViewBuilder
    private var popupBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    @ViewBuilder
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(iconColor.opacity(Glass.headerTintOpacity)))
    }

    @ViewBuilder
    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.sectionTintOpacity)))
    }

    @ViewBuilder
    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(sectionBackground)
            .overlay(sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func tintedSectionCard<Content: View>(
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular.tint(tint.opacity(Glass.headerTintOpacity)))
            )
            .overlay(sectionBorder)
            .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var loadingSection: some View {
        sectionCard {
            ProgressView()
                .padding(20)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            popupHeader

            if isLoading {
                loadingSection
            } else {
                infoRows
            }
        }
        .frame(width: Layout.popupWidth)
        .padding(.top, 10)
        .background(popupBackground)
        .overlay(popupBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .task { await loadInfo() }
    }

    private var popupHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: host.systemIconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(host.hostDisplayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.headerHPadding)
        .padding(.vertical, 10)
        .background {
            tintedSectionCard(tint: iconColor) {
                Color.clear
            }
        }
        .padding(.horizontal, 10)
    }

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                infoRow(entry)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, Layout.dividerInset)
                }
            }
        }
        .padding(.vertical, 4)
        .background {
            sectionCard {
                Color.clear
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func infoRow(_ entry: DeviceInfoEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: Layout.labelWidth, alignment: .trailing)
            Text(entry.value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.rowHPadding)
        .padding(.vertical, 4)
    }

    private func appendEntry(_ result: inout [DeviceInfoEntry], label: String, value: String) {
        guard !value.isEmpty else { return }
        result.append(DeviceInfoEntry(label: label, value: value))
    }

    private func safeDisplayedHostName() -> String? {
        let displayHN = host.hostName
        guard !displayHN.isEmpty, displayHN != "(nil)", displayHN != host.name else { return nil }

        if displayHN.contains("@") || (displayHN.contains(":") && !displayHN.contains(".")) {
            return host.hostDisplayName
        }

        return displayHN
    }

    private func resolvedHostType() -> String {
        host.deviceClass.label.isEmpty ? host.nodeTypeLabel : host.deviceClass.label
    }

    private func formattedBonjourServices() -> String {
        host.bonjourServices
            .map {
                $0.replacingOccurrences(of: "._tcp.", with: "")
                    .replacingOccurrences(of: "_", with: "")
            }
            .sorted()
            .joined(separator: ", ")
    }

    private func appendBaseEntries(_ result: inout [DeviceInfoEntry]) {
        if let safeHostName = safeDisplayedHostName() {
            appendEntry(&result, label: "Hostname", value: safeHostName)
        }

        appendEntry(&result, label: "IP", value: host.hostDisplayName)
        appendEntry(&result, label: "Type", value: resolvedHostType())

        let services = formattedBonjourServices()
        appendEntry(&result, label: "Services", value: services)
    }

    private func resolveMACAddress() async -> String? {
        if let mac = host.macAddress {
            return mac
        }

        let ip = host.hostIP.isEmpty ? host.hostName : host.hostIP
        guard !ip.isEmpty, ip != "(nil)", !ip.contains("@") else { return nil }
        return await arpLookup(ip: ip)
    }

    private func appendMACEntries(_ result: inout [DeviceInfoEntry], mac: String) async {
        appendEntry(&result, label: "MAC", value: mac)
        let vendor = await MACVendorService.shared.lookup(mac)
        appendEntry(&result, label: "Vendor", value: vendor)
    }

    private func appendPortAndShares(_ result: inout [DeviceInfoEntry]) {
        if host.port > 0 {
            appendEntry(&result, label: "Port", value: String(host.port))
        }

        if host.sharesLoaded && !host.shares.isEmpty {
            let shares = host.shares.map { $0.name }.joined(separator: ", ")
            appendEntry(&result, label: "Shares", value: shares)
        }
    }

    // MARK: - Load device info async (never blocks MainActor)
    private func loadInfo() async {
        var result: [DeviceInfoEntry] = []

        appendBaseEntries(&result)

        if let mac = await resolveMACAddress() {
            await appendMACEntries(&result, mac: mac)
        }

        if host.deviceClass == .printer || host.nodeType == .printer {
            let ippInfo = await probePrinterIPP(host: host)
            result.append(contentsOf: ippInfo)
        }

        appendPortAndShares(&result)

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

    private func extractedPrinterValue(in output: String, tag: String) -> String? {
        guard let startRange = output.range(of: tag + "</b>") else { return nil }
        guard let endRange = output[startRange.upperBound...].range(of: "<") else { return nil }

        let value = String(output[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
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
            if let value = extractedPrinterValue(in: output, tag: tag) {
                result.append(DeviceInfoEntry(label: label, value: value))
            }
        }
        return result
    }

    private var iconColor: Color {
        switch host.deviceClass {
            case .mac:
                return .blue
            case .router, .repeater, .networkSwitch:
                return .orange
            case .printer:
                return .purple
            case .nas:
                return .green
            case .iPhone, .iPad, .androidPhone, .androidTablet:
                return .teal
            case .windowsPC:
                return .indigo
            case .linuxServer:
                return .mint
            case .smartTV, .mediaBox, .gameConsole:
                return .pink
            case .camera:
                return .red
            default:
                return .secondary
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
