// NetworkNeighborhoodProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour-based network host discovery via NetServiceBrowser

import Foundation
import Network

// MARK: - Discovers LAN hosts via Bonjour
@MainActor
final class NetworkNeighborhoodProvider: NSObject, ObservableObject {

    static let shared = NetworkNeighborhoodProvider()

    @Published private(set) var hosts: [NetworkHost] = []
    @Published private(set) var isScanning: Bool = false

    private var browsers: [NetServiceBrowser] = []

    // MARK: -
    override private init() { super.init() }

    // MARK: - Start discovery for all service types
    func startDiscovery() {
        guard !isScanning else { return }
        log.info("[Network] startDiscovery — scanning Bonjour services")
        hosts.removeAll()
        browsers.removeAll()
        isScanning = true
        for serviceType in NetworkServiceType.allCases {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: serviceType.rawValue, inDomain: "local.")
            browsers.append(browser)
        }
    }

    // MARK: - Stop all browsers
    func stopDiscovery() {
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        isScanning = false
        log.info("[Network] stopDiscovery")
    }

    // MARK: - Internal helpers called from MainActor
    fileprivate func removeHostByName(_ name: String) {
        hosts.removeAll { $0.name == name }
    }

    fileprivate func addResolvedHost(name: String, hostName: String, port: Int, serviceType: NetworkServiceType) {
        guard !hosts.contains(where: { $0.hostName == hostName }) else { return }
        let host = NetworkHost(name: name, hostName: hostName, port: port, serviceType: serviceType)
        hosts.append(host)
        log.info("[Network] resolved: \(name) → \(hostName):\(port) (\(serviceType.displayName))")
    }

    fileprivate func removePendingByName(_: String) {
        // pendingServices removed — no-op kept for delegate symmetry
    }
}

// MARK: - NetServiceBrowserDelegate
extension NetworkNeighborhoodProvider: NetServiceBrowserDelegate {

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // NetService is not Sendable — do not cross actor boundary with it.
        // Resolution result arrives in netServiceDidResolveAddress on the same thread.
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let name = service.name
        Task { @MainActor in
            self.removeHostByName(name)
        }
    }

    nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in
            self.isScanning = !self.browsers.isEmpty
        }
    }
}

// MARK: - NetServiceDelegate
extension NetworkNeighborhoodProvider: NetServiceDelegate {

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        // Extract all values before crossing actor boundary
        let name = sender.name
        let hostName = sender.hostName ?? sender.name
        let port = sender.port
        let senderType = sender.type
        let serviceType = NetworkServiceType.allCases.first {
            senderType.contains($0.rawValue.prefix(8))
        } ?? .smb

        Task { @MainActor in
            self.addResolvedHost(name: name, hostName: hostName, port: port, serviceType: serviceType)
            self.removePendingByName(name)
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let name = sender.name
        Task { @MainActor in
            self.removePendingByName(name)
            log.debug("[Network] failed to resolve: \(name)")
        }
    }
}
