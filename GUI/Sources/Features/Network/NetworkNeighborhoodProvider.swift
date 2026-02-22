// NetworkNeighborhoodProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 20.02.2026 — tree expand: fetchShares per host, nodeType detection
// Refactored: 22.02.2026 — NetFS share enumeration (Finder-compatible); hostname normalization;
//                          in-place hostName update; layout recursion fix
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour-based network host discovery + lazy share enumeration via NetFS

import Foundation
import Network
import Darwin

// MARK: - Discovers LAN hosts via Bonjour + FritzBox, enumerates shares via NetFS
@MainActor
final class NetworkNeighborhoodProvider: NSObject, ObservableObject {

    static let shared = NetworkNeighborhoodProvider()

    @Published private(set) var hosts: [NetworkHost] = []
    @Published private(set) var isScanning: Bool = false

    private var browsers: [NetServiceBrowser] = []
    private var scanGeneration: Int = 0

    // MARK: - Printer service types
    nonisolated static let printerServiceTypes: Set<String> = [
        "_ipp._tcp.",
        "_ipps._tcp.",
        "_pdl-datastream._tcp.",
        "_printer._tcp.",
        "_fax-ipp._tcp.",
    ]

    override private init() { super.init() }

    // MARK: - Start discovery
    func startDiscovery() {
        guard !isScanning else { return }
        log.info("[Network] startDiscovery — scanning Bonjour + FritzBox")
        hosts.removeAll()
        browsers.removeAll()
        isScanning = true
        scanGeneration += 1
        let generation = scanGeneration

        let allTypes = NetworkServiceType.allCases.map { $0.rawValue } + Array(Self.printerServiceTypes)
        for type in allTypes {
            let browser = NetServiceBrowser()
            browser.schedule(in: .main, forMode: .common)
            browser.delegate = self
            browser.searchForServices(ofType: type, inDomain: "local.")
            browsers.append(browser)
        }

        Task {
            let fritzHosts = await FritzBoxDiscovery.activeHosts()
            await MainActor.run {
                guard self.scanGeneration == generation else { return }
                for fh in fritzHosts {
                    let nameLower = fh.name.lowercased()
                    guard !nameLower.contains("fritz") &&
                          !nameLower.contains("iphone") &&
                          !nameLower.contains("ipad") &&
                          !nameLower.contains("irobot") &&
                          !fh.ip.isEmpty
                    else { continue }
                    guard !self.hosts.contains(where: {
                        $0.name.lowercased() == nameLower || $0.hostName == fh.ip
                    }) else { continue }
                    guard !self.isLocalhost(ip: fh.ip) else {
                        log.debug("[Network] skipping localhost: \(fh.name) (\(fh.ip))")
                        continue
                    }
                    self.addResolvedHost(name: fh.name, hostName: fh.name,
                                        port: 445, serviceType: .smb,
                                        isPrinter: false, bonjourType: nil)
                    log.info("[Network] FritzBox host: \(fh.name) (\(fh.ip))")
                }
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(12))
            await MainActor.run {
                guard self.scanGeneration == generation, self.isScanning else { return }
                self.stopDiscovery()
                log.info("[Network] auto-stopped after timeout")
            }
        }
    }

    // MARK: - Detect if IP belongs to this Mac
    private func isLocalhost(ip: String) -> Bool {
        if ip == "127.0.0.1" || ip == "::1" { return true }
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let c = cur {
            if let sa = c.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) {
                var addr = sockaddr_in()
                withUnsafeMutableBytes(of: &addr) {
                    $0.copyMemory(from: UnsafeRawBufferPointer(UnsafeBufferPointer(start: sa, count: 1)))
                }
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                if String(cString: buf) == ip { return true }
            }
            cur = c.pointee.ifa_next
        }
        return false
    }

    // MARK: - Stop all browsers
    func stopDiscovery() {
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        isScanning = false
        log.info("[Network] stopDiscovery — \(hosts.count) hosts found")
        runFingerprintPass()
    }

    // MARK: - Expand: load shares for host via NetFS
    func fetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        guard hosts[idx].isExpandable else { return }
        guard !hosts[idx].sharesLoaded else { return }
        hosts[idx].sharesLoading = true
        log.info("[Network] fetchShares for \(hosts[idx].name)")
        let host = hosts[idx]
        let shares = await NetworkShareEnumerator.shares(for: host)
        if let i = hosts.firstIndex(where: { $0.id == hostID }) {
            hosts[i].shares      = shares
            hosts[i].sharesLoaded  = true
            hosts[i].sharesLoading = false
        }
        log.info("[Network] shares for \(host.name): \(shares.map(\.name))")
    }

    // MARK: - Internal: add or update host — in-place update preserves id/shares/state
    fileprivate func addResolvedHost(
        name: String, hostName: String, port: Int,
        serviceType: NetworkServiceType?, isPrinter: Bool,
        bonjourType: String? = nil
    ) {
        let nodeType: NetworkNodeType = isPrinter ? .printer : .fileServer
        let svcType = serviceType ?? .smb
        if let idx = hosts.firstIndex(where: { $0.name == name }) {
            if let bt = bonjourType { hosts[idx].bonjourServices.insert(bt) }
            if hostName != name && hostName != "(nil)" && !hostName.isEmpty {
                hosts[idx].hostName = hostName
                if port > 0 { hosts[idx].port = port }
                log.info("[Network] updated hostName for '\(name)' → \(hostName)")
            }
            return
        }
        var host = NetworkHost(name: name, hostName: hostName, port: port,
                               serviceType: svcType, nodeType: nodeType)
        if let bt = bonjourType { host.bonjourServices.insert(bt) }
        if let quick = NetworkDeviceFingerprinter.classifyByServices(host.bonjourServices) {
            host.deviceClass = quick
        } else {
            let nameLower = name.lowercased()
            let hostLower = hostName.lowercased()
            if nameLower.contains("fritz") || hostLower.contains("fritz") ||
               name == "192-168-178-1" || hostName == "192.168.178.1" {
                host.deviceClass = .router
                host.nodeType    = .generic
            }
        }
        hosts.append(host)
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[Network] added: '\(name)' hostName=\(hostName) port=\(port) isPrinter=\(isPrinter) deviceClass=\(host.deviceClass.label)")
    }

    // MARK: - Deep fingerprint after scan completes
    private func runFingerprintPass() {
        let candidates = hosts.filter {
            $0.deviceClass != .router && $0.deviceClass != .printer
        }
        guard !candidates.isEmpty else { return }
        log.info("[Fingerprint] starting pass for \(candidates.map(\.name))")
        Task {
            for host in candidates {
                let fp = await NetworkDeviceFingerprinter.probe(
                    hostName: host.hostName,
                    bonjourServices: host.bonjourServices
                )
                if let idx = self.hosts.firstIndex(where: { $0.id == host.id }) {
                    self.hosts[idx].deviceClass = fp.deviceClass
                    log.info("[Fingerprint] '\(host.name)' → \(fp.deviceClass.label)  ports=\(fp.openPorts.sorted())")
                }
            }
            log.info("[Fingerprint] pass complete")
        }
    }

    // MARK: - Retry share fetch after auth (resets sharesLoaded flag)
    func retryFetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        hosts[idx].sharesLoaded = false
        hosts[idx].shares = []
        await fetchShares(for: hostID)
    }

    fileprivate func removeHostByName(_ name: String) {
        hosts.removeAll { $0.name == name }
    }
}

// MARK: - NetServiceBrowserDelegate
extension NetworkNeighborhoodProvider: NetServiceBrowserDelegate {

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        log.info("[Network] didFind service='\(service.name)' type='\(service.type)' moreComing=\(moreComing)")
        let name        = service.name
        let senderType  = service.type
        let isPrinter   = NetworkNeighborhoodProvider.printerServiceTypes.contains { senderType.contains($0) }
        let serviceType = isPrinter ? nil : NetworkServiceType.allCases.first { senderType.contains($0.rawValue) }
        Task { @MainActor in
            guard self.isScanning else { return }
            self.addResolvedHost(name: name, hostName: name, port: serviceType?.defaultPort ?? 445,
                                 serviceType: serviceType, isPrinter: isPrinter,
                                 bonjourType: senderType)
        }
        service.delegate = self
        service.resolve(withTimeout: 8.0)
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        let name = service.name
        log.info("[Network] didRemove service='\(name)'")
        Task { @MainActor in self.removeHostByName(name) }
    }

    nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        log.debug("[Network] browserDidStopSearch")
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        log.warning("[Network] didNotSearch error=\(errorDict)")
    }
}

// MARK: - NetServiceDelegate
extension NetworkNeighborhoodProvider: NetServiceDelegate {

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        let name       = sender.name
        let hostName   = sender.hostName ?? "(nil)"
        let port       = sender.port
        let senderType = sender.type
        log.info("[Network] resolved '\(name)' → \(hostName):\(port) type=\(senderType)")
        let isPrinter   = NetworkNeighborhoodProvider.printerServiceTypes.contains { senderType.contains($0) }
        let serviceType = isPrinter ? nil : NetworkServiceType.allCases.first { senderType.contains($0.rawValue) }
        Task { @MainActor in
            // Allow late resolve after scan stopped — updates hostName for NetFS
            self.addResolvedHost(name: name, hostName: hostName, port: port,
                                 serviceType: serviceType, isPrinter: isPrinter)
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("[Network] didNotResolve '\(sender.name)' error=\(errorDict)")
    }
}
