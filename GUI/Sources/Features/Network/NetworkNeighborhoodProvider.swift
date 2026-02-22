// NetworkNeighborhoodProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 20.02.2026 — tree expand: fetchShares per host, nodeType detection
// Refactored: 22.02.2026 — NetFS shares; hostname normalization; layout recursion fix
// Refactored: 22.02.2026 — iPhone/iPad via _apple-mobdev2; SASCHA from FritzBox; fritz=Router
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour-based network host discovery + lazy share enumeration

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

    // MARK: - Service types that indicate a printer
    nonisolated static let printerServiceTypes: Set<String> = [
        "_ipp._tcp.", "_ipps._tcp.", "_pdl-datastream._tcp.",
        "_printer._tcp.", "_fax-ipp._tcp.",
    ]

    // MARK: - Mobile device service type (iPhone / iPad)
    nonisolated static let mobileServiceType = "_apple-mobdev2._tcp."

    override private init() { super.init() }

    // MARK: - Start discovery
    func startDiscovery() {
        guard !isScanning else { return }
        log.info("[Network] startDiscovery — Bonjour + FritzBox")
        hosts.removeAll()
        browsers.removeAll()
        isScanning = true
        scanGeneration += 1
        let generation = scanGeneration

        // All file-sharing + printer + mobile service types
        let serviceTypes = NetworkServiceType.allCases.map { $0.rawValue }
            + Array(Self.printerServiceTypes)
            + [Self.mobileServiceType]

        for type in serviceTypes {
            let browser = NetServiceBrowser()
            browser.schedule(in: .main, forMode: .common)
            browser.delegate = self
            browser.searchForServices(ofType: type, inDomain: "local.")
            browsers.append(browser)
        }

        // FritzBox TR-064 — discover ALL LAN hosts (PC, Mac, NAS, etc.)
        Task {
            let fritzHosts = await FritzBoxDiscovery.activeHosts()
            await MainActor.run {
                guard self.scanGeneration == generation else { return }
                for fh in fritzHosts {
                    guard !fh.ip.isEmpty else { continue }
                    // Skip this Mac's own IPs
                    guard !self.isLocalhostIP(fh.ip) else {
                        log.debug("[FritzBox] skip localhost: \(fh.name) (\(fh.ip))")
                        continue
                    }
                    // Skip if already added via Bonjour
                    let nameLower = fh.name.lowercased()
                    guard !self.hosts.contains(where: {
                        $0.name.lowercased() == nameLower || $0.hostName == fh.ip
                    }) else { continue }

                    self.addResolvedHost(name: fh.name, hostName: fh.name,
                                        port: 445, serviceType: .smb,
                                        isPrinter: false, bonjourType: nil)
                    log.info("[FritzBox] added host: \(fh.name) (\(fh.ip))")
                }
            }
        }

        // Auto-stop after 12 seconds
        Task {
            try? await Task.sleep(for: .seconds(12))
            await MainActor.run {
                guard self.scanGeneration == generation, self.isScanning else { return }
                self.stopDiscovery()
                log.info("[Network] auto-stopped after 12s timeout")
            }
        }
    }

    // MARK: - Detect if IP belongs to this Mac
    private func isLocalhostIP(_ ip: String) -> Bool {
        if ip == "127.0.0.1" || ip == "::1" { return true }
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let c = cur {
            defer { cur = c.pointee.ifa_next }
            guard let sa = c.pointee.ifa_addr,
                  sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            var addr = sockaddr_in()
            withUnsafeMutableBytes(of: &addr) {
                $0.copyMemory(from: UnsafeRawBufferPointer(UnsafeBufferPointer(start: sa, count: 1)))
            }
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &addr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
            if String(cString: buf) == ip { return true }
        }
        return false
    }

    // MARK: - Stop all browsers
    func stopDiscovery() {
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        isScanning = false
        log.info("[Network] stopDiscovery — \(hosts.count) hosts")
        runFingerprintPass()
    }

    // MARK: - Fetch shares for a host (lazy, triggered by expand)
    func fetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        guard hosts[idx].isExpandable, !hosts[idx].sharesLoaded else { return }
        hosts[idx].sharesLoading = true
        log.info("[Network] fetchShares for '\(hosts[idx].name)'")
        let host = hosts[idx]
        let shares = await NetworkShareEnumerator.shares(for: host)
        if let i = hosts.firstIndex(where: { $0.id == hostID }) {
            hosts[i].shares       = shares
            hosts[i].sharesLoaded  = true
            hosts[i].sharesLoading = false
        }
        log.info("[Network] '\(host.name)' shares: \(shares.map(\.name))")
    }

    // MARK: - Retry after auth
    func retryFetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        hosts[idx].sharesLoaded = false
        hosts[idx].shares = []
        await fetchShares(for: hostID)
    }

    // MARK: - Normalize name for dedup (strips .local .local. .fritz.box)
    private func normalizedName(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".fritz.box", with: "")
    }

    // MARK: - Add or in-place update host (preserves id/shares/expanded state)
    fileprivate func addResolvedHost(
        name: String, hostName: String, port: Int,
        serviceType: NetworkServiceType?,
        isPrinter: Bool,
        bonjourType: String? = nil,
        isMobile: Bool = false
    ) {
        // Skip This Mac - not shown in Network Neighborhood (Finder behavior)
        if isLocalhostByName(name: name, hostName: hostName) {
            log.debug("[Network] skip localhost: \(name)")
            return
        }
        // Dedup by normalized name - merges kira-macpro + kira-macpro.local
        let norm = normalizedName(name)
        if let idx = hosts.firstIndex(where: { self.normalizedName($0.name) == norm }) {
            if let bt = bonjourType { hosts[idx].bonjourServices.insert(bt) }
            if hostName != "(nil)" && !hostName.isEmpty && hostName.contains(".") {
                hosts[idx].hostName = hostName
                if port > 0 { hosts[idx].port = port }
                log.debug("[Network] updated hn \(hosts[idx].name) -> \(hostName)")
            }
            reclassifyIfNeeded(idx: idx)
            return
        }

        let nodeType: NetworkNodeType = isMobile ? .mobileDevice
                                      : isPrinter ? .printer
                                      : .fileServer
        let svcType = serviceType ?? .smb
        var host = NetworkHost(name: name, hostName: hostName, port: port,
                               serviceType: svcType, nodeType: nodeType)
        if let bt = bonjourType { host.bonjourServices.insert(bt) }


        // Classify by services
        if host.deviceClass == .unknown,
           let quick = NetworkDeviceFingerprinter.classifyByServices(host.bonjourServices) {
            host.deviceClass = quick
        }
        // Classify by name (catches fritz-box, router, iPhone, iPad, NAS)
        if host.deviceClass == .unknown || host.deviceClass == .windowsPC {
            if let byName = NetworkDeviceFingerprinter.classifyByName(name, hostName: hostName) {
                host.deviceClass = byName
                if byName.isRouter { host.nodeType = .generic }
                if byName.isMobile { host.nodeType = .mobileDevice }
            }
        }
        // Mobile node type always overrides
        if isMobile && host.deviceClass == .unknown { host.deviceClass = .iPhone }

        hosts.append(host)
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[Network] added '\(name)' hn=\(hostName) class=\(host.deviceClass.label) localhost=\(host.isLocalhost)")
    }

    // MARK: - Re-classify existing host when bonjourServices updated
    private func reclassifyIfNeeded(idx: Int) {
        let host = hosts[idx]
        guard host.deviceClass == .unknown || host.deviceClass == .windowsPC else { return }
        if let cls = NetworkDeviceFingerprinter.classifyByServices(host.bonjourServices) {
            hosts[idx].deviceClass = cls
            if cls.isRouter { hosts[idx].nodeType = .generic }
        }
    }

    // MARK: - Is this host this Mac?
    private func isLocalhostByName(name: String, hostName: String) -> Bool {
        let macName = Host.current().localizedName ?? ""
        let n = name.lowercased()
        let hn = hostName.lowercased()
        let mac = macName.lowercased()
        return n == mac || n == mac.replacing(" ", with: "-") || hn == "127.0.0.1" || hn == "::1"
    }

    // MARK: - Deep fingerprint pass after scan stops
    private func runFingerprintPass() {
        let candidates = hosts.filter {
            $0.deviceClass == .unknown && !$0.isLocalhost
        }
        guard !candidates.isEmpty else { return }
        log.info("[Fingerprint] probing: \(candidates.map(\.name))")
        Task {
            for host in candidates {
                let fp = await NetworkDeviceFingerprinter.probe(
                    hostName: host.hostName,
                    bonjourServices: host.bonjourServices,
                    name: host.name
                )
                if let idx = self.hosts.firstIndex(where: { $0.id == host.id }) {
                    self.hosts[idx].deviceClass = fp.deviceClass
                    if fp.deviceClass.isRouter { self.hosts[idx].nodeType = .generic }
                    log.info("[Fingerprint] '\(host.name)' → \(fp.deviceClass.label) ports=\(fp.openPorts.sorted())")
                }
            }
        }
    }

    fileprivate func removeHostByName(_ name: String) {
        hosts.removeAll { $0.name == name }
    }
}

// MARK: - NetServiceBrowserDelegate
extension NetworkNeighborhoodProvider: NetServiceBrowserDelegate {

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
    ) {
        let name       = service.name
        let senderType = service.type
        log.info("[Bonjour] found '\(name)' type=\(senderType)")

        let isMobile  = senderType.contains("mobdev")
        let isPrinter = !isMobile && NetworkNeighborhoodProvider.printerServiceTypes
            .contains { senderType.contains($0) }
        let serviceType = (isMobile || isPrinter) ? nil
            : NetworkServiceType.allCases.first { senderType.contains($0.rawValue) }

        Task { @MainActor in
            guard self.isScanning else { return }
            // Dedup mobile devices by MAC prefix (same device on multiple interfaces)
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
        service.delegate = self
        service.resolve(withTimeout: 8.0)
    }

    // MARK: - Extract MAC key from Bonjour name (xx:xx:xx:xx:xx:xx@...)
    nonisolated private func macKey(from name: String) -> String? {
        let s = name.lowercased()
        guard s.count >= 17 else { return nil }
        let candidate = String(s.prefix(17))
        let parts = candidate.components(separatedBy: ":")
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }) else { return nil }
        return candidate
    }

    // MARK: - Parse friendly name for mobile (MAC@addr → "iPhone" / "iPad")
    nonisolated private func mobileDisplayName(from bonjourName: String) -> String {
        // Name format: "b4:1b:b0:6d:1a:22@fe80::...supportsRP-24"
        // We'll refine after resolve; for now use MAC prefix
        if let at = bonjourName.firstIndex(of: "@") {
            let mac = String(bonjourName[bonjourName.startIndex..<at])
            return "Apple Device (\(mac.suffix(5)))"
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
        let name       = sender.name
        let hostName   = sender.hostName ?? "(nil)"
        let port       = sender.port
        let senderType = sender.type
        log.info("[Bonjour] resolved '\(name)' → \(hostName):\(port)")

        let isMobile  = senderType.contains("mobdev")
        let isPrinter = !isMobile && NetworkNeighborhoodProvider.printerServiceTypes
            .contains { senderType.contains($0) }
        let serviceType = (isMobile || isPrinter) ? nil
            : NetworkServiceType.allCases.first { senderType.contains($0.rawValue) }

        Task { @MainActor in
            let displayName = isMobile ? self.refinedMobileName(hostName: hostName, rawName: name) : name
            self.addResolvedHost(
                name: displayName, hostName: hostName,
                port: port, serviceType: serviceType,
                isPrinter: isPrinter,
                isMobile: isMobile
            )
        }
    }

    // MARK: - Resolve hostname to friendly mobile name
    // iPad/iPhone in hostName > short hostname > MAC suffix
    nonisolated private func refinedMobileName(hostName: String, rawName: String) -> String {
        let hn = hostName.lowercased()
        let shortHN = hn.components(separatedBy: ".").first ?? hn
        if hn.contains("ipad") { return "iPad (" + shortHN + ")" }
        if hn.contains("iphone") { return "iPhone (" + shortHN + ")" }
        let looksLikeIP = shortHN.components(separatedBy: "-").count == 4
        if !looksLikeIP && !shortHN.isEmpty && shortHN != "(nil)" {
            return "Apple Device (" + shortHN + ")"
        }
        if let at = rawName.firstIndex(of: "@") {
            return "Apple Device (" + String(rawName[rawName.startIndex..<at].suffix(8)) + ")"
        }
        return "Apple Device"
    }
    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("[Bonjour] didNotResolve '\(sender.name)' \(errorDict)")
    }
}
