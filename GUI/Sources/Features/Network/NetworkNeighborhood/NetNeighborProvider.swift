// NetworkNeighborhoodProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
//             BRW/iRobot classify; mobile rename via FritzBox; SASCHA=Windows via fingerprint
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour-based network host discovery + lazy share enumeration + FritzBox TR-064

import Darwin
import Foundation
import Network

// MARK: - Discovers LAN hosts via Bonjour + FritzBox, enumerates shares via NetFS
@MainActor
final class NetworkNeighborhoodProvider: NSObject, ObservableObject {

    static let shared = NetworkNeighborhoodProvider()

    @Published private(set) var hosts: [NetworkHost] = []
    @Published private(set) var isScanning: Bool = false

    private var browsers: [NetServiceBrowser] = []
    // Keep NetService objects alive until resolved (otherwise delegate never fires)
    var pendingServices: [NetService] = []
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
        pendingServices.removeAll()
        isScanning = true
        scanGeneration += 1
        let generation = scanGeneration

        let serviceTypes =
            NetworkServiceType.allCases.map { $0.rawValue }
            + Array(Self.printerServiceTypes)
            + [Self.mobileServiceType]

        for svcType in serviceTypes {
            let browser = NetServiceBrowser()
            browser.schedule(in: .main, forMode: .common)
            browser.delegate = self
            browser.searchForServices(ofType: svcType, inDomain: "local.")
            browsers.append(browser)
        }

        // FritzBox TR-064 — all LAN hosts including Windows PCs, NAS, mobiles
        Task {
            let fritzHosts = await FritzBoxDiscovery.activeHosts()
            await MainActor.run {
                guard self.scanGeneration == generation else { return }
                self.mergeFritzHosts(fritzHosts)
            }
        }

        // Auto-stop after 14 seconds
        Task {
            try? await Task.sleep(for: .seconds(14))
            await MainActor.run {
                guard self.scanGeneration == generation, self.isScanning else { return }
                self.stopDiscovery()
                log.info("[Network] auto-stopped after 14s timeout")
            }
        }
    }

    // MARK: - Merge FritzBox DHCP host list into discovered hosts
    func mergeFritzHosts(_ fritzHosts: [FritzBoxHost]) {
        let routerIPs: Set<String> = ["192.168.178.1", "192.168.178.46"]
        let ipToIdx = buildHostIPIndex()

        for fritzHost in fritzHosts {
            guard !shouldSkipFritzHost(fritzHost, routerIPs: routerIPs) else { continue }

            if let existingIndex = findExistingHostIndex(for: fritzHost, ipToIdx: ipToIdx) {
                updateExistingHost(at: existingIndex, with: fritzHost)
                continue
            }

            appendNewFritzHost(fritzHost)
        }
    }

    // MARK: - Detect if IP belongs to this Mac
    func isLocalhostIP(_ ip: String) -> Bool {
        if ip == "127.0.0.1" || ip == "::1" { return true }
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let c = cur {
            defer { cur = c.pointee.ifa_next }
            guard let sa = c.pointee.ifa_addr,
                sa.pointee.sa_family == UInt8(AF_INET)
            else { continue }
            // Safe sockaddr → sockaddr_in cast via withMemoryRebound
            let matches = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var sinCopy = sin.pointee
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &sinCopy.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                return String(decoding: buf.prefix(while: { $0 != 0 }).map(UInt8.init), as: UTF8.self) == ip
            }
            if matches { return true }
        }
        return false
    }

    // MARK: - Stop all browsers + release pending services
    func stopDiscovery() {
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        pendingServices.removeAll()
        isScanning = false
        log.info("[Network] stopDiscovery — \(hosts.count) hosts")
        runFingerprintPass()
    }

    // MARK: - Fetch shares (lazy, on expand)
    func fetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        guard hosts[idx].isExpandable, !hosts[idx].sharesLoaded else { return }
        hosts[idx].sharesLoading = true
        hosts[idx].shareLoadState = .idle
        log.info("[Network] fetchShares for '\(hosts[idx].name)'")
        let host = hosts[idx]
        let result = await NetworkShareEnumerator.enumerateShares(for: host)
        if let i = hosts.firstIndex(where: { $0.id == hostID }) {
            hosts[i].shares = result.shares
            hosts[i].sharesLoaded = true
            hosts[i].sharesLoading = false
            hosts[i].shareLoadState = shareLoadState(for: result)
        }
        log.info("[Network] '\(host.name)' shares: \(result.shares.map(\.name)) state=\(shareLoadState(for: result).rawValue)")
    }

    func retryFetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        hosts[idx].sharesLoaded = false
        hosts[idx].sharesLoading = false
        hosts[idx].shares = []
        hosts[idx].shareLoadState = .idle
        await fetchShares(for: hostID)
    }

    private func shareLoadState(for result: NetworkShareEnumerationResult) -> NetworkShareLoadState {
        switch result {
        case .shares:
            return .loaded
        case .noShares:
            return .noShares
        case .authRequired:
            return .authRequired
        case .unavailable:
            return .unavailable
        }
    }

    // MARK: - Normalize name for dedup
    // strips .local .local. .fritz.box; dots→dashes so fritz.box == fritz-box
    private func normalizedName(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".fritz.box", with: "")
            .replacingOccurrences(of: ".", with: "-")
    }

    // MARK: - Add or update host (dedup by normalized name)
    func addResolvedHost(
        name: String, hostName: String, port: Int,
        serviceType: NetworkServiceType?,
        isPrinter: Bool,
        bonjourType: String? = nil,
        isMobile: Bool = false,
        fritzMAC: String? = nil,
        isOffline: Bool = false
    ) {
        guard !isLocalhostByName(name: name, hostName: hostName) else {
            log.debug("[Network] skip localhost: \(name)")
            return
        }

        let norm = normalizedName(name)
        if let idx = hosts.firstIndex(where: { normalizedName($0.name) == norm }) {
            if let bt = bonjourType { hosts[idx].bonjourServices.insert(bt) }
            // Update hostName only if new one is better (contains "." = DNS, not raw MAC)
            let newHNBetter =
                !hostName.isEmpty && hostName != "(nil)"
                && (hostName.contains(".") || hostName.first?.isNumber == true)
                && !hostName.contains("@")
            if newHNBetter {
                hosts[idx].hostName = hostName
                if port > 0 { hosts[idx].port = port }
            }
            reclassifyIfNeeded(idx: idx)
            // Rename mobile placeholder if resolved name is better
            if isMobile {
                let existing = hosts[idx].name.lowercased()
                let isPlaceholder = existing.hasPrefix("apple device")
                if isPlaceholder && !name.hasPrefix("Apple Device") {
                    hosts[idx].name = name
                    log.info("[Network] mobile renamed '\(hosts[idx].name)' → '\(name)'")
                }
            }
            return
        }

        let nodeType: NetworkNodeType =
            isMobile
            ? .mobileDevice
            : isPrinter
                ? .printer
                : .fileServer
        var host = NetworkHost(
            name: name, hostName: hostName, port: port,
            serviceType: serviceType ?? .smb, nodeType: nodeType)
        if let bt = bonjourType { host.bonjourServices.insert(bt) }
        // Store MAC: from FritzBox or extracted from mobile Bonjour name
        if host.rawMAC == nil {
            if let fm = fritzMAC, !fm.isEmpty {
                host.rawMAC = fm
            } else if isMobile {
                if let at = name.firstIndex(of: "@") {
                    host.rawMAC = String(name[name.startIndex..<at]).uppercased()
                } else if let at = hostName.firstIndex(of: "@") {
                    host.rawMAC = String(hostName[hostName.startIndex..<at]).uppercased()
                }
            }
        }
        host.isOffline = isOffline

        // Classify by Bonjour services
        if host.deviceClass == .unknown,
            let cls = NetworkDeviceFingerprinter.classifyByServices(host.bonjourServices)
        {
            host.deviceClass = cls
            if cls.isRouter { host.nodeType = .generic }
        }
        // Classify by name
        if host.deviceClass == .unknown {
            if let cls = NetworkDeviceFingerprinter.classifyByName(name, hostName: hostName) {
                host.deviceClass = cls
                if cls.isRouter { host.nodeType = .generic }
                if cls.isMobile { host.nodeType = .mobileDevice }
                if cls == .printer { host.nodeType = .printer }
            }
        }
        // Fallback classification from name patterns
        if host.deviceClass == .unknown {
            let nl = name.lowercased()
            if isMobile {
                host.deviceClass = .iPhone
            } else if nl.hasPrefix("brw") {
                host.deviceClass = .printer
                host.nodeType = .printer
            } else if nl.hasPrefix("irobot") {
                host.deviceClass = .nas
                host.nodeType = .generic
            } else if nl.contains("fritz.repeater") {
                host.deviceClass = .router
                host.nodeType = .generic
            } else if nl == "ipad" {
                host.deviceClass = .iPad
                host.nodeType = .mobileDevice
            } else if nl == "iphone" || nl.hasPrefix("iphone") || nl.contains("-iphone") {
                host.deviceClass = .iPhone
                host.nodeType = .mobileDevice
            }
        }

        hosts.append(host)
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[Network] added '\(name)' hn=\(hostName) class=\(host.deviceClass.label)")
    }

    func reclassifyIfNeeded(idx: Int) {
        guard hosts[idx].deviceClass == .unknown else { return }
        if let cls = NetworkDeviceFingerprinter.classifyByServices(hosts[idx].bonjourServices) {
            hosts[idx].deviceClass = cls
            if cls.isRouter { hosts[idx].nodeType = .generic }
        }
    }

    func isLocalhostByName(name: String, hostName: String) -> Bool {
        let macName = Host.current().localizedName ?? ""
        let n = name.lowercased()
        let hn = hostName.lowercased()
        let mac = macName.lowercased()
        return n == mac || n == mac.replacing(" ", with: "-") || hn == "127.0.0.1" || hn == "::1"
    }

    // MARK: - Fingerprint pass (after scan stops)
    func runFingerprintPass() {
        let candidates = hosts.filter { $0.deviceClass == .unknown && !$0.isOffline }
        let webCandidates = hosts.filter { $0.probedWebURL == nil && !$0.isOffline }
        if !candidates.isEmpty {
            log.info("[Fingerprint] probing: \(candidates.map(\.name))")
        }
        Task {
            // Device class fingerprinting (port scan)
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
            // Web UI probe for all online hosts
            await probeWebUI(for: webCandidates)
        }
    }

    // MARK: - Web UI probe — fires concurrently for all candidates
    func probeWebUI(for candidates: [NetworkHost]) async {
        guard !candidates.isEmpty else { return }
        log.info("[WebUI] probing \(candidates.count) hosts")
        var hitCount = 0
        await withTaskGroup(of: (NetworkHost.ID, URL?).self) { group in
            for host in candidates {
                group.addTask { @concurrent in
                    let url = await WebUIProber.probe(host: host)
                    return (host.id, url)
                }
            }
            for await (id, url) in group {
                if let url, let idx = self.hosts.firstIndex(where: { $0.id == id }) {
                    self.hosts[idx].probedWebURL = url
                    hitCount += 1
                }
            }
        }
        log.info("[WebUI] probe complete hits=\(hitCount) misses=\(candidates.count - hitCount)")
    }

    func removeHostByName(_ name: String) {
        hosts.removeAll { $0.name == name }
    }

    private func buildHostIPIndex() -> [String: Int] {
        var ipToIdx: [String: Int] = [:]

        for (index, host) in hosts.enumerated() where !host.hostName.isEmpty && !host.hostName.contains("@") {
            ipToIdx[host.hostName] = index

            let stripped = host.hostName
                .replacingOccurrences(of: ".local.", with: "")
                .replacingOccurrences(of: ".local", with: "")

            if stripped != host.hostName {
                ipToIdx[stripped] = index
            }
        }

        return ipToIdx
    }

    private func shouldSkipFritzHost(_ fritzHost: FritzBoxHost, routerIPs: Set<String>) -> Bool {
        guard !fritzHost.ip.isEmpty, !isLocalhostIP(fritzHost.ip) else {
            log.debug("[FritzBox] skip localhost: \(fritzHost.name) (\(fritzHost.ip))")
            return true
        }

        if routerIPs.contains(fritzHost.ip) {
            log.debug("[FritzBox] skip router IP duplicate: \(fritzHost.name) (\(fritzHost.ip))")
            return true
        }

        return false
    }

    private func findExistingHostIndex(for fritzHost: FritzBoxHost, ipToIdx: [String: Int]) -> Int? {
        let normalizedFritzName = normalizedName(fritzHost.name)
        let fritzNameLowercased = fritzHost.name.lowercased()
        let isFritzMobile = isLikelyMobileFritzHostName(fritzNameLowercased)

        if let index = ipToIdx[fritzHost.ip] {
            return index
        }

        return hosts.firstIndex { host in
            let normalizedHostName = normalizedName(host.name)
            if normalizedHostName == normalizedFritzName {
                return true
            }

            if isFritzMobile {
                return isMobilePlaceholderHostName(host.name)
            }

            return false
        }
    }

    private func updateExistingHost(at index: Int, with fritzHost: FritzBoxHost) {
        updateExistingHostAddress(at: index, with: fritzHost)
        updateExistingHostMAC(at: index, with: fritzHost)
        updateExistingHostOfflineState(at: index, with: fritzHost)
        renameExistingPlaceholderIfNeeded(at: index, with: fritzHost)
    }

    private func updateExistingHostAddress(at index: Int, with fritzHost: FritzBoxHost) {
        if hosts[index].hostName.contains("@") || hosts[index].hostName.isEmpty {
            hosts[index].hostName = fritzHost.ip
            log.debug("[FritzBox] updated IP \(hosts[index].name) → \(fritzHost.ip)")
        }
    }

    private func updateExistingHostMAC(at index: Int, with fritzHost: FritzBoxHost) {
        if hosts[index].rawMAC == nil && !fritzHost.mac.isEmpty {
            hosts[index].rawMAC = fritzHost.mac
        }
    }

    private func updateExistingHostOfflineState(at index: Int, with fritzHost: FritzBoxHost) {
        if !fritzHost.isActive {
            hosts[index].isOffline = true
        }
    }

    private func renameExistingPlaceholderIfNeeded(at index: Int, with fritzHost: FritzBoxHost) {
        let existingName = hosts[index].name
        guard isMobilePlaceholderHostName(existingName) else { return }
        guard !fritzHost.name.isEmpty else { return }

        hosts[index].name = fritzHost.name
        log.info("[FritzBox] renamed '\(existingName)' → '\(fritzHost.name)' (\(fritzHost.ip))")
    }

    private func appendNewFritzHost(_ fritzHost: FritzBoxHost) {
        addResolvedHost(
            name: fritzHost.name,
            hostName: fritzHost.ip,
            port: 445,
            serviceType: .smb,
            isPrinter: false,
            bonjourType: nil,
            fritzMAC: fritzHost.mac,
            isOffline: !fritzHost.isActive
        )
        log.info("[FritzBox] added '\(fritzHost.name)' ip=\(fritzHost.ip) active=\(fritzHost.isActive)")
    }

    private func isLikelyMobileFritzHostName(_ lowercasedName: String) -> Bool {
        lowercasedName == "ipad"
            || lowercasedName.hasPrefix("iphone")
            || lowercasedName.contains("-iphone")
    }

    private func isMobilePlaceholderHostName(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        return lowercasedName.hasPrefix("apple device")
            || lowercasedName.hasPrefix("iphone (")
            || lowercasedName.hasPrefix("ipad (")
    }
}
