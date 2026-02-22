// NetworkNeighborhoodProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 20.02.2026 — tree expand: fetchShares per host, nodeType detection
// Refactored: 22.02.2026 — fix hostname normalization for smbutil; allow late resolve after scan stop;
//                          in-place hostName update preserves id/shares/deviceClass
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour-based network host discovery + lazy share enumeration

import Foundation
import Network
import Darwin

// MARK: - Discovers LAN hosts via Bonjour + enumerates shares on demand
@MainActor
final class NetworkNeighborhoodProvider: NSObject, ObservableObject {

    static let shared = NetworkNeighborhoodProvider()

    @Published private(set) var hosts: [NetworkHost] = []
    @Published private(set) var isScanning: Bool = false

    private var browsers: [NetServiceBrowser] = []
    private var scanGeneration: Int = 0

    // MARK: - Printer service types (used to classify nodeType)
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

    // MARK: - Expand: load shares for host
    func fetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        guard hosts[idx].isExpandable else { return }
        guard !hosts[idx].sharesLoaded else { return }
        hosts[idx].sharesLoading = true
        log.info("[Network] fetchShares for \(hosts[idx].name)")
        let host = hosts[idx]
        let shares = await resolveShares(host: host)
        if let i = hosts.firstIndex(where: { $0.id == hostID }) {
            hosts[i].shares = shares
            hosts[i].sharesLoaded = true
            hosts[i].sharesLoading = false
        }
        log.info("[Network] shares for \(host.name): \(shares.map(\.name))")
    }

    // MARK: - Share resolution strategy
    private func resolveShares(host: NetworkHost) async -> [NetworkShare] {
        let mounted = mountedShares(for: host)
        if !mounted.isEmpty { return mounted }
        if host.serviceType == .smb {
            let smbShares = await smbUtilShares(host: host)
            if !smbShares.isEmpty { return smbShares }
        }
        return []
    }

    // MARK: - /Volumes/ scan for already-mounted shares from this host
    private func mountedShares(for host: NetworkHost) -> [NetworkShare] {
        guard let vols = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: [.volumeIsLocalKey]
        ) else { return [] }
        return vols.compactMap { vol -> NetworkShare? in
            guard let vals = try? vol.resourceValues(forKeys: [.volumeIsLocalKey]),
                  vals.volumeIsLocal == false else { return nil }
            let volName = vol.lastPathComponent
            let hostFragments = [host.name, host.hostName]
                .flatMap { $0.components(separatedBy: ".") }
                .map { $0.lowercased() }
            let volLower = volName.lowercased()
            guard hostFragments.contains(where: { !$0.isEmpty && volLower.contains($0) }) else { return nil }
            return NetworkShare(name: volName, url: vol)
        }
    }

    // MARK: - Normalize hostname for smbutil: ensure .local suffix when resolve failed
    private func smbHost(_ host: NetworkHost) -> String {
        let hn = host.hostName
        if hn == host.name || hn == "(nil)" || hn.isEmpty {
            return host.name.hasSuffix(".local") ? host.name : "\(host.name).local"
        }
        return hn
    }

    // MARK: - smbutil view //[user:pass@]host (lists shares using Keychain credentials)
    private func smbUtilShares(host: NetworkHost) async -> [NetworkShare] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let resolvedHost = self.smbHost(host)
                log.info("[Network] smbutil target host: \(resolvedHost) (original hostName=\(host.hostName))")
                let target: String
                if let creds = NetworkAuthService.load(for: host.hostName) {
                    let enc = creds.password
                        .addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? creds.password
                    target = "//\(creds.user):\(enc)@\(resolvedHost)"
                } else {
                    target = "//\(resolvedHost)"
                }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/smbutil")
                process.arguments = ["view", target]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do { try process.run() } catch {
                    log.warning("[Network] smbutil view failed to start for \(host.hostName): \(error)")
                    continuation.resume(returning: [])
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
                    if process.isRunning { process.terminate() }
                }
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                log.debug("[Network] smbutil view \(host.hostName) exit=\(process.terminationStatus) output=\(output.prefix(300))")
                let shares = self.parseSmbUtilOutput(output, host: host)
                continuation.resume(returning: shares)
            }
        }
    }

    // MARK: - Parse smbutil view output
    nonisolated private func parseSmbUtilOutput(_ output: String, host: NetworkHost) -> [NetworkShare] {
        var shares: [NetworkShare] = []
        let lines = output.components(separatedBy: .newlines)
        var inTable = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("------") { inTable = true; continue }
            guard inTable, !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let diskIdx = parts.firstIndex(where: { $0.lowercased() == "disk" }),
                  diskIdx > 0 else { continue }
            let shareName = parts[0..<diskIdx].joined(separator: " ")
            guard !shareName.hasSuffix("$") else { continue }
            let scheme = host.serviceType == .afp ? "afp" : "smb"
            let encoded = shareName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? shareName
            if let url = URL(string: "\(scheme)://\(host.hostName)/\(encoded)") {
                shares.append(NetworkShare(name: shareName, url: url))
            }
        }
        log.info("[Network] parseSmbUtil \(host.hostName): found \(shares.count) shares: \(shares.map(\.name))")
        return shares
    }

    // MARK: - Internal: add or update host — in-place hostName update preserves id/shares/deviceClass
    fileprivate func addResolvedHost(
        name: String, hostName: String, port: Int,
        serviceType: NetworkServiceType?, isPrinter: Bool,
        bonjourType: String? = nil
    ) {
        let nodeType: NetworkNodeType = isPrinter ? .printer : .fileServer
        let svcType = serviceType ?? .smb
        if let idx = hosts.firstIndex(where: { $0.name == name }) {
            if let bt = bonjourType { hosts[idx].bonjourServices.insert(bt) }
            // In-place update — preserves id so View expanded state is not lost
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
        // Resolve for actual .local hostname — delegate kept alive until resolved
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
        log.info("[Network] netServiceDidResolveAddress name='\(name)' host='\(hostName)' port=\(port) type='\(senderType)'")
        let isPrinter = NetworkNeighborhoodProvider.printerServiceTypes.contains { senderType.contains($0) }
        let serviceType = isPrinter ? nil :
            NetworkServiceType.allCases.first { senderType.contains($0.rawValue) }
        log.info("[Network] classified: isPrinter=\(isPrinter) serviceType=\(String(describing: serviceType?.rawValue))")
        Task { @MainActor in
            // Allow late resolve even after scan stopped — updates hostName for smbutil
            self.addResolvedHost(
                name: name,
                hostName: hostName,
                port: port,
                serviceType: serviceType,
                isPrinter: isPrinter
            )
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("[Network] didNotResolve '\(sender.name)' error=\(errorDict)")
    }
}
