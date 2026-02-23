// NetworkNeighborhoodProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 22.02.2026 — Stage 11: fix resolve (keep NetService alive); fritz.box dedup;
//             BRW/iRobot classify; mobile rename via FritzBox; SASCHA=Windows via fingerprint
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour-based network host discovery + lazy share enumeration + FritzBox TR-064

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
    // Keep NetService objects alive until resolved (otherwise delegate never fires)
    private var pendingServices: [NetService] = []
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

        let serviceTypes = NetworkServiceType.allCases.map { $0.rawValue }
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
    private func mergeFritzHosts(_ fritzHosts: [FritzBoxHost]) {
        // Skip router IPs — already found via Bonjour as fritz-box / fritz.repeater
        let routerIPs: Set<String> = ["192.168.178.1", "192.168.178.46"]
        // Build IP→index map for fast lookup (dedup BRW vs Brother by same IP)
        // Include both raw hostName and stripped .local suffix
        var ipToIdx = [String: Int]()
        for (i, h) in hosts.enumerated() where !h.hostName.isEmpty && !h.hostName.contains("@") {
            ipToIdx[h.hostName] = i
            // Also index by stripped .local suffix (Bonjour: "kira-macpro.local" → FritzBox: "192.168.178.x")
            let stripped = h.hostName
                .replacingOccurrences(of: ".local.", with: "")
                .replacingOccurrences(of: ".local", with: "")
            if stripped != h.hostName { ipToIdx[stripped] = i }
        }

        for fh in fritzHosts {
            guard !fh.ip.isEmpty, !isLocalhostIP(fh.ip) else {
                log.debug("[FritzBox] skip localhost: \(fh.name) (\(fh.ip))")
                continue
            }
            // Skip secondary router entries — Bonjour already found fritz-box/fritz.repeater
            if routerIPs.contains(fh.ip) {
                log.debug("[FritzBox] skip router IP duplicate: \(fh.name) (\(fh.ip))")
                continue
            }
            let fhNorm  = normalizedName(fh.name)
            let fhNameL = fh.name.lowercased()
            let isFritzMobile = fhNameL == "ipad" || fhNameL.hasPrefix("iphone") || fhNameL.contains("-iphone")

            // Try to find matching existing host (by name OR by IP)
            if let idx = ipToIdx[fh.ip] ?? hosts.firstIndex(where: {
                let norm = normalizedName($0.name)
                if norm == fhNorm { return true }
                // Mobile: match any unresolved "Apple Device (...)" placeholder
                if isFritzMobile {
                    let n = $0.name.lowercased()
                    return n.hasPrefix("apple device") || n.hasPrefix("iphone (") || n.hasPrefix("ipad (")
                }
                return false
            }) {
                // Update IP (hostName for mobile was MAC@addr — replace with real IP)
                if hosts[idx].hostName.contains("@") || hosts[idx].hostName.isEmpty {
                    hosts[idx].hostName = fh.ip
                    log.debug("[FritzBox] updated IP \(hosts[idx].name) → \(fh.ip)")
                }
                // Store FritzBox MAC if not already saved
                if hosts[idx].rawMAC == nil && !fh.mac.isEmpty {
                    hosts[idx].rawMAC = fh.mac
                }
                // Mark inactive hosts
                if !fh.isActive { hosts[idx].isOffline = true }
                // Rename placeholder → real FritzBox name
                let existing = hosts[idx].name
                let isPlaceholder = existing.lowercased().hasPrefix("apple device")
                    || existing.lowercased().hasPrefix("iphone (")
                    || existing.lowercased().hasPrefix("ipad (")
                if isPlaceholder && !fh.name.isEmpty {
                    hosts[idx].name = fh.name
                    log.info("[FritzBox] renamed '\(existing)' → '\(fh.name)' (\(fh.ip))")
                }
                continue
            }

            // New host — only known to FritzBox (Windows PC, NAS, unknown device)
            addResolvedHost(name: fh.name, hostName: fh.ip,
                            port: 445, serviceType: .smb,
                            isPrinter: false, bonjourType: nil,
                            fritzMAC: fh.mac, isOffline: !fh.isActive)
            log.info("[FritzBox] added '\(fh.name)' ip=\(fh.ip) active=\(fh.isActive)")
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
            // Safe sockaddr → sockaddr_in cast via withMemoryRebound
            let matches = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var sinCopy = sin.pointee
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &sinCopy.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                return String(cString: buf) == ip
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
        log.info("[Network] fetchShares for '\(hosts[idx].name)'")
        let host = hosts[idx]
        let shares = await NetworkShareEnumerator.shares(for: host)
        if let i = hosts.firstIndex(where: { $0.id == hostID }) {
            hosts[i].shares        = shares
            hosts[i].sharesLoaded  = true
            hosts[i].sharesLoading = false
        }
        log.info("[Network] '\(host.name)' shares: \(shares.map(\.name))")
    }

    func retryFetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        hosts[idx].sharesLoaded = false
        hosts[idx].shares = []
        await fetchShares(for: hostID)
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
    fileprivate func addResolvedHost(
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
            let newHNBetter = !hostName.isEmpty && hostName != "(nil)"
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

        let nodeType: NetworkNodeType = isMobile ? .mobileDevice
                                      : isPrinter ? .printer
                                      : .fileServer
        var host = NetworkHost(name: name, hostName: hostName, port: port,
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
           let cls = NetworkDeviceFingerprinter.classifyByServices(host.bonjourServices) {
            host.deviceClass = cls
            if cls.isRouter { host.nodeType = .generic }
        }
        // Classify by name
        if host.deviceClass == .unknown {
            if let cls = NetworkDeviceFingerprinter.classifyByName(name, hostName: hostName) {
                host.deviceClass = cls
                if cls.isRouter  { host.nodeType = .generic }
                if cls.isMobile  { host.nodeType = .mobileDevice }
                if cls == .printer { host.nodeType = .printer }
            }
        }
        // Fallback classification from name patterns
        if host.deviceClass == .unknown {
            let nl = name.lowercased()
            if isMobile                           { host.deviceClass = .iPhone }
            else if nl.hasPrefix("brw")           { host.deviceClass = .printer;  host.nodeType = .printer }
            else if nl.hasPrefix("irobot")        { host.deviceClass = .nas;      host.nodeType = .generic }
            else if nl.contains("fritz.repeater") { host.deviceClass = .router;   host.nodeType = .generic }
            else if nl == "ipad"                  { host.deviceClass = .iPad;     host.nodeType = .mobileDevice }
            else if nl == "iphone" || nl.hasPrefix("iphone") || nl.contains("-iphone") {
                host.deviceClass = .iPhone; host.nodeType = .mobileDevice
            }
        }

        hosts.append(host)
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[Network] added '\(name)' hn=\(hostName) class=\(host.deviceClass.label)")
    }

    private func reclassifyIfNeeded(idx: Int) {
        guard hosts[idx].deviceClass == .unknown else { return }
        if let cls = NetworkDeviceFingerprinter.classifyByServices(hosts[idx].bonjourServices) {
            hosts[idx].deviceClass = cls
            if cls.isRouter { hosts[idx].nodeType = .generic }
        }
    }

    private func isLocalhostByName(name: String, hostName: String) -> Bool {
        let macName = Host.current().localizedName ?? ""
        let n  = name.lowercased()
        let hn = hostName.lowercased()
        let mac = macName.lowercased()
        return n == mac || n == mac.replacing(" ", with: "-") || hn == "127.0.0.1" || hn == "::1"
    }

    // MARK: - Fingerprint pass (after scan stops)
    private func runFingerprintPass() {
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
        await withTaskGroup(of: (NetworkHost.ID, URL?).self) { group in
            for host in candidates {
                group.addTask {
                    let url = await WebUIProber.probe(host: host)
                    return (host.id, url)
                }
            }
            for await (id, url) in group {
                if let url, let idx = self.hosts.firstIndex(where: { $0.id == id }) {
                    self.hosts[idx].probedWebURL = url
                    log.info("[WebUI] '\(self.hosts[idx].name)' → \(url)")
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

        // Set delegate and start resolve BEFORE the Task (nonisolated context)
        // This prevents NetService from being deallocated before resolve fires
        service.delegate = self
        service.resolve(withTimeout: 10.0)

        Task { @MainActor in
            guard self.isScanning else { return }
            // Dedup mobile by MAC prefix (same device on multiple interfaces)
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

    // MARK: - Extract MAC xx:xx:xx:xx:xx:xx from Bonjour mobile name
    nonisolated private func macKey(from name: String) -> String? {
        let s = name.lowercased()
        guard s.count >= 17 else { return nil }
        let candidate = String(s.prefix(17))
        let parts = candidate.components(separatedBy: ":")
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }) else { return nil }
        return candidate
    }

    // MARK: - Temporary name before resolve: "Apple Device (b0:6d:1a:22)"
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
            let displayName = isMobile
                ? self.refinedMobileName(hostName: hostName, rawName: name)
                : name
            self.addResolvedHost(
                name: displayName, hostName: hostName,
                port: port, serviceType: serviceType,
                isPrinter: isPrinter,
                isMobile: isMobile
            )
            // pendingServices no longer needed (resolve done)
            self.pendingServices.removeAll(keepingCapacity: false)
        }
    }

    // MARK: - Resolve real hostname → friendly mobile name
    // NetService.resolve gives: Iakovs-mabila.local → iPhone (iakovs-mabila)
    //                           iPad-v-I.local      → iPad (ipad-v-i)
    nonisolated private func refinedMobileName(hostName: String, rawName: String) -> String {
        let hn = hostName
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .lowercased()
        guard !hn.isEmpty && hn != "(nil)" else {
            // Fallback to MAC suffix
            if let at = rawName.firstIndex(of: "@") {
                return "Apple Device (" + String(rawName[rawName.startIndex..<at].suffix(8)) + ")"
            }
            return "Apple Device"
        }
        // Looks like IP address? Use MAC suffix
        let isIP = hn.components(separatedBy: "-").count == 4
            && hn.components(separatedBy: "-").allSatisfy { Int($0) != nil }
        let label = isIP
            ? (macKey(from: rawName).map { String($0.suffix(8)) } ?? hn)
            : hn
        if hn.contains("ipad")                                { return "iPad (\(label))" }
        if hn.contains("iphone") || hn.contains("phone")     { return "iPhone (\(label))" }
        if hn.contains("mabila") || hn.hasSuffix("-s-iphone") { return "iPhone (\(label))" }
        return "Apple Device (\(label))"
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("[Bonjour] didNotResolve '\(sender.name)' \(errorDict)")
    }
}
