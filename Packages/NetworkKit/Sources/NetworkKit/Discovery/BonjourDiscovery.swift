// BonjourDiscovery.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Discovers SMB/AFP hosts on the local network via Bonjour (NetServiceBrowser)

import Foundation

// MARK: - Bonjour-based network host discovery
@MainActor
public final class BonjourDiscovery: NSObject, ObservableObject {

    @Published public private(set) var hosts: [NetworkHost] = []
    @Published public private(set) var isScanning: Bool = false

    // Active browsers keyed by service type
    private var browsers: [String: NetServiceBrowser] = [:]
    // Resolving services (kept alive during resolution)
    private var resolvingServices: Set<NetService> = []

    // Service types to discover
    private let serviceTypes = [
        "_smb._tcp.",
        "_afpovertcp._tcp.",
        "_device-info._tcp.",
    ]

    // MARK: - Start discovery
    public func startDiscovery() {
        guard !isScanning else { return }
        isScanning = true
        hosts.removeAll()
        for type in serviceTypes {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browsers[type] = browser
            browser.searchForServices(ofType: type, inDomain: "local.")
        }
    }

    // MARK: - Stop discovery
    public func stopDiscovery() {
        browsers.values.forEach { $0.stop() }
        browsers.removeAll()
        resolvingServices.removeAll()
        isScanning = false
    }

    // MARK: - Add host, deduplicating by hostName
    private func addHost(_ host: NetworkHost) {
        guard !hosts.contains(where: { $0.hostName == host.hostName }) else { return }
        hosts.append(host)
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - NetServiceBrowserDelegate
extension BonjourDiscovery: @preconcurrency NetServiceBrowserDelegate {

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        resolvingServices.insert(service)
        service.resolve(withTimeout: 5.0)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        hosts.removeAll { $0.hostName == service.hostName }
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        // Silently ignore — user may not have network access
    }
}

// MARK: - NetServiceDelegate
extension BonjourDiscovery: @preconcurrency NetServiceDelegate {

    public func netServiceDidResolveAddress(_ sender: NetService) {
        defer { resolvingServices.remove(sender) }
        guard let hostName = sender.hostName, !hostName.isEmpty else { return }

        // Extract IP addresses
        let addresses: [String] = (sender.addresses ?? []).compactMap { data in
            var storage = sockaddr_storage()
            (data as NSData).getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
            var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let ptr = withUnsafePointer(to: &storage) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
            }
            guard getnameinfo(ptr, socklen_t(data.count), &buf, socklen_t(NI_MAXHOST), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
            let ip = String(cString: buf)
            // Filter out IPv6 link-local
            return ip.hasPrefix("fe80") ? nil : ip
        }

        let host = NetworkHost(
            name: sender.name,
            hostName: hostName,
            addresses: addresses,
            serviceType: sender.type
        )
        addHost(host)
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolvingServices.remove(sender)
    }
}
