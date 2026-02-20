// NetworkNeighborhoodProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 20.02.2026 — tree expand: fetchShares per host, nodeType detection
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour-based network host discovery + lazy share enumeration

import Foundation
import Network

// MARK: - Discovers LAN hosts via Bonjour + enumerates shares on demand
@MainActor
final class NetworkNeighborhoodProvider: NSObject, ObservableObject {

    static let shared = NetworkNeighborhoodProvider()

    @Published private(set) var hosts: [NetworkHost] = []
    @Published private(set) var isScanning: Bool = false

    private var browsers: [NetServiceBrowser] = []

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
        log.info("[Network] startDiscovery — scanning Bonjour services")
        hosts.removeAll()
        browsers.removeAll()
        isScanning = true

        // File server types
        for serviceType in NetworkServiceType.allCases {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: serviceType.rawValue, inDomain: "local.")
            browsers.append(browser)
        }
        // Printer types
        for printerType in Self.printerServiceTypes {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: printerType, inDomain: "local.")
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

    // MARK: - Expand: load shares for host
    // Strategy: check already-mounted volumes in /Volumes first (instant),
    // then try smb://host/ listing via NSTask smbutil (best-effort, no Finder).
    func fetchShares(for hostID: NetworkHost.ID) async {
        guard let idx = hosts.firstIndex(where: { $0.id == hostID }) else { return }
        guard hosts[idx].isExpandable else { return }
        guard !hosts[idx].sharesLoaded else { return }  // already fetched

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
        // 1. Check /Volumes/ — already mounted shares are immediately available
        let mounted = mountedShares(for: host)
        if !mounted.isEmpty { return mounted }

        // 2. Try smbutil lookup (works without auth for publicly listed shares)
        if host.serviceType == .smb {
            let smbShares = await smbUtilShares(host: host)
            if !smbShares.isEmpty { return smbShares }
        }

        // 3. Fallback: return single entry "Connect…" pointing to root
        if let rootURL = host.mountURL {
            return [NetworkShare(name: "Connect…", url: rootURL)]
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
            // Match by hostname fragment
            let hostFragments = [host.name, host.hostName]
                .flatMap { $0.components(separatedBy: ".") }
                .map { $0.lowercased() }
            let volLower = volName.lowercased()
            guard hostFragments.contains(where: { !$0.isEmpty && volLower.contains($0) }) else { return nil }
            return NetworkShare(name: volName, url: vol)
        }
    }

    // MARK: - smbutil lookup -L host (list shares without mounting)
    private func smbUtilShares(host: NetworkHost) async -> [NetworkShare] {
        // smbutil look -L <host> lists shares anonymously when guest access is allowed.
        // Output lines starting with "Disk" or share names are extracted.
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/smbutil")
                process.arguments = ["look", host.hostName]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()  // suppress errors
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(returning: [])
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let shares = self.parseSmbUtilOutput(output, host: host)
                continuation.resume(returning: shares)
            }
        }
    }

    // MARK: - Parse smbutil look output
    nonisolated private func parseSmbUtilOutput(_ output: String, host: NetworkHost) -> [NetworkShare] {
        // smbutil look output example:
        //   Using IP: 192.168.1.10
        //   Share        Type   Comments
        //   ------       ----   --------
        //   Public       Disk
        //   homes        Disk
        //   IPC$         Pipe   IPC Service
        var shares: [NetworkShare] = []
        let lines = output.components(separatedBy: .newlines)
        var inTable = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("----") { inTable = true; continue }
            guard inTable, !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard let shareName = parts.first,
                  !shareName.hasSuffix("$"),    // skip hidden IPC$ / ADMIN$
                  parts.count >= 2,
                  parts[1].lowercased() == "disk"
            else { continue }

            let scheme = host.serviceType == .afp ? "afp" : "smb"
            if let url = URL(string: "\(scheme)://\(host.hostName)/\(shareName)") {
                shares.append(NetworkShare(name: shareName, url: url))
            }
        }
        return shares
    }

    // MARK: - Internal: add resolved host
    fileprivate func addResolvedHost(
        name: String, hostName: String, port: Int,
        serviceType: NetworkServiceType?, isPrinter: Bool
    ) {
        guard !hosts.contains(where: { $0.hostName == hostName }) else { return }
        let nodeType: NetworkNodeType = isPrinter ? .printer : .fileServer
        let svcType = serviceType ?? .smb
        let host = NetworkHost(name: name, hostName: hostName, port: port,
                               serviceType: svcType, nodeType: nodeType)
        hosts.append(host)
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[Network] resolved: \(name) → \(hostName):\(port) type=\(nodeType)")
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
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        let name = service.name
        Task { @MainActor in self.removeHostByName(name) }
    }

    nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in self.isScanning = !self.browsers.isEmpty }
    }
}

// MARK: - NetServiceDelegate
extension NetworkNeighborhoodProvider: NetServiceDelegate {

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        let name     = sender.name
        let hostName = sender.hostName ?? sender.name
        let port     = sender.port
        let senderType = sender.type

        // Classify: is it a printer or file server?
        let isPrinter = NetworkNeighborhoodProvider.printerServiceTypes
            .contains(where: { senderType.contains($0.prefix(8)) })

        let serviceType = isPrinter ? nil :
            NetworkServiceType.allCases.first { senderType.contains($0.rawValue.prefix(8)) }

        Task { @MainActor in
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
        log.debug("[Network] failed to resolve: \(sender.name)")
    }
}
