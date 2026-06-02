// NetNeighborProvider+Bonjour.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: NetServiceBrowserDelegate + NetServiceDelegate extensions.
//   Extracted from NetNeighborProvider.swift for single responsibility.

import Foundation

// MARK: - NetServiceBrowserDelegate

extension NetworkNeighborhoodProvider: NetServiceBrowserDelegate {

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
    ) {
        let name = service.name
        let senderType = service.type
        log.info("[Bonjour] found '\(name)' type=\(senderType)")
        let isMobile = senderType.contains("mobdev")
        let isPrinter =
            !isMobile
            && NetworkNeighborhoodProvider.printerServiceTypes
                .contains { senderType.contains($0) }
        let serviceType =
            (isMobile || isPrinter)
            ? nil
            : NetworkServiceType.allCases.first { senderType.contains($0.rawValue) }
        service.delegate = self
        service.resolve(withTimeout: 10.0)
        Task { @MainActor in
            guard self.isScanning else { return }
            if isMobile, let mk = self.macKey(from: name) {
                if self.hosts.contains(where: {
                    self.macKey(from: $0.hostName) == mk || self.macKey(from: $0.name) == mk
                }) {
                    log.debug("[Bonjour] skip duplicate mobile MAC=\(mk)")
                    return
                }
            }
            let displayName = isMobile ? self.mobileDisplayName(from: name) : name
            self.addResolvedHost(
                name: displayName, hostName: name,
                port: serviceType?.defaultPort ?? 0,
                serviceType: serviceType,
                isPrinter: isPrinter,
                bonjourType: senderType,
                isMobile: isMobile
            )
        }
    }

    nonisolated private func macKey(from name: String) -> String? {
        let s = name.lowercased()
        guard s.count >= 17 else { return nil }
        let candidate = String(s.prefix(17))
        let parts = candidate.components(separatedBy: ":")
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }) else { return nil }
        return candidate
    }

    nonisolated private func mobileDisplayName(from bonjourName: String) -> String {
        if let at = bonjourName.firstIndex(of: "@") {
            let mac = String(bonjourName[bonjourName.startIndex..<at])
            return "Apple Device (\(mac.suffix(11)))"
        }
        return bonjourName
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool
    ) {
        let name = service.name
        Task { @MainActor in self.removeHostByName(name) }
    }

    nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        log.debug("[Bonjour] browserDidStopSearch")
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]
    ) {
        log.warning("[Bonjour] didNotSearch error=\(errorDict)")
    }
}

// MARK: - NetServiceDelegate

extension NetworkNeighborhoodProvider: NetServiceDelegate {

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        let hostName = sender.hostName ?? "(nil)"
        let resolvedHostName = ipv4Address(from: sender.addresses) ?? hostName
        let port = sender.port
        let senderType = sender.type
        let senderID = ObjectIdentifier(sender)
        log.info("[Bonjour] resolved '\(name)' → \(resolvedHostName):\(port)")
        let isMobile = senderType.contains("mobdev")
        let isPrinter =
            !isMobile
            && NetworkNeighborhoodProvider.printerServiceTypes
                .contains { senderType.contains($0) }
        let serviceType =
            (isMobile || isPrinter)
            ? nil
            : NetworkServiceType.allCases.first { senderType.contains($0.rawValue) }
        Task { @MainActor in
            let displayName =
                isMobile
                ? self.refinedMobileName(hostName: resolvedHostName, rawName: name)
                : name
            self.addResolvedHost(
                name: displayName, hostName: resolvedHostName,
                port: port, serviceType: serviceType,
                isPrinter: isPrinter,
                isMobile: isMobile
            )
            self.pendingServices.removeAll { ObjectIdentifier($0) == senderID }
        }
    }

    nonisolated private func refinedMobileName(hostName: String, rawName: String) -> String {
        let hn =
            hostName
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .lowercased()
        guard !hn.isEmpty && hn != "(nil)" else {
            if let at = rawName.firstIndex(of: "@") {
                return "Apple Device (" + String(rawName[rawName.startIndex..<at].suffix(8)) + ")"
            }
            return "Apple Device"
        }
        let isIP =
            hn.components(separatedBy: "-").count == 4
            && hn.components(separatedBy: "-").allSatisfy { Int($0) != nil }
        let label =
            isIP
            ? (macKey(from: rawName).map { String($0.suffix(8)) } ?? hn)
            : hn
        if hn.contains("ipad") { return "iPad (\(label))" }
        if hn.contains("iphone") || hn.contains("phone") { return "iPhone (\(label))" }
        if hn.contains("mabila") || hn.hasSuffix("-s-iphone") { return "iPhone (\(label))" }
        return "Apple Device (\(label))"
    }

    // MARK: - IPv4 address from resolved Bonjour service
    nonisolated private func ipv4Address(from addresses: [Data]?) -> String? {
        guard let addresses else { return nil }
        for addressData in addresses {
            let result = addressData.withUnsafeBytes { rawBuffer -> String? in
                guard let baseAddress = rawBuffer.baseAddress else { return nil }
                let socketAddress = baseAddress.assumingMemoryBound(to: sockaddr.self)
                guard socketAddress.pointee.sa_family == sa_family_t(AF_INET) else { return nil }
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let status = getnameinfo(socketAddress, socklen_t(addressData.count), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
                guard status == 0 else { return nil }
                let endIndex = hostBuffer.firstIndex(of: 0) ?? hostBuffer.endIndex
                let bytes = hostBuffer[..<endIndex].map { UInt8(bitPattern: $0) }
                return String(decoding: bytes, as: UTF8.self)
            }
            if let result { return result }
        }
        return nil
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("[Bonjour] didNotResolve '\(sender.name)' \(errorDict)")
    }
}
