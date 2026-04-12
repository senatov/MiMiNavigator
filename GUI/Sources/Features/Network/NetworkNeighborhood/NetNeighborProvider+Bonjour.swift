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
        let port = sender.port
        let senderType = sender.type
        let senderID = ObjectIdentifier(sender)
        log.info("[Bonjour] resolved '\(name)' → \(hostName):\(port)")
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
                ? self.refinedMobileName(hostName: hostName, rawName: name)
                : name
            self.addResolvedHost(
                name: displayName, hostName: hostName,
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

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("[Bonjour] didNotResolve '\(sender.name)' \(errorDict)")
    }
}
