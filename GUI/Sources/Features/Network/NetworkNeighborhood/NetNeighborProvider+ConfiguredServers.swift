// NetNeighborProvider+ConfiguredServers.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 02.06.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Adds saved local SMB/AFP server configurations to Network Neighborhood.

import Foundation

// MARK: - Configured server discovery
extension NetworkNeighborhoodProvider {

    // MARK: - Merge saved local servers
    func mergeConfiguredLocalServers() {
        let servers = RemoteServerStore.shared.servers.filter(shouldShowConfiguredServer)
        guard !servers.isEmpty else { return }
        for server in servers {
            mergeConfiguredServer(server)
        }
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[Network] configured local servers merged count=\(servers.count)")
    }

    // MARK: - Configured server filters
    private func shouldShowConfiguredServer(_ server: RemoteServer) -> Bool {
        guard server.remoteProtocol == .smb || server.remoteProtocol == .afp else { return false }
        guard !server.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return isLocalConfiguredHost(server.host)
    }

    private func isLocalConfiguredHost(_ host: String) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedHost.isEmpty else { return false }
        if normalizedHost.contains(".") == false { return true }
        if normalizedHost.hasSuffix(".local") || normalizedHost.hasSuffix(".local.") { return true }
        if normalizedHost.hasSuffix(".fritz.box") { return true }
        return isPrivateIPv4(normalizedHost)
    }

    private func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        guard parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        return false
    }

    // MARK: - Merge one configured server
    private func mergeConfiguredServer(_ server: RemoteServer) {
        let hostName = server.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = server.displayName
        let port = server.port > 0 ? server.port : server.remoteProtocol.defaultPort
        let serviceType = serviceType(for: server.remoteProtocol)
        guard let serviceType else { return }
        if let idx = existingConfiguredHostIndex(displayName: displayName, hostName: hostName) {
            mergeConfiguredShare(from: server, into: idx)
            hosts[idx].bonjourServices.insert(serviceType.rawValue)
            if hosts[idx].deviceClass == .unknown {
                applyConfiguredClassification(to: idx, server: server)
            }
            return
        }
        var host = NetworkHost(
            name: displayName,
            hostName: hostName,
            port: port,
            serviceType: serviceType,
            nodeType: .fileServer
        )
        host.bonjourServices.insert(serviceType.rawValue)
        if let cls = NetworkDeviceFingerprinter.classifyByName(displayName, hostName: hostName) {
            host.deviceClass = cls
        }
        host.shares = configuredShares(for: server)
        host.sharesLoaded = !host.shares.isEmpty
        host.shareLoadState = host.shares.isEmpty ? .idle : .loaded
        hosts.append(host)
    }

    private func existingConfiguredHostIndex(displayName: String, hostName: String) -> Int? {
        let normalizedDisplayName = normalizedConfiguredKey(displayName)
        let normalizedHostName = normalizedConfiguredKey(hostName)
        return hosts.firstIndex { host in
            normalizedConfiguredKey(host.name) == normalizedDisplayName
                || normalizedConfiguredKey(host.hostName) == normalizedHostName
                || normalizedConfiguredKey(host.name) == normalizedHostName
                || normalizedConfiguredKey(host.hostName) == normalizedDisplayName
        }
    }

    private func normalizedConfiguredKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".fritz.box", with: "")
    }

    // MARK: - Shares from configured server
    private func configuredShares(for server: RemoteServer) -> [NetworkShare] {
        guard let share = configuredShare(for: server) else { return [] }
        return [share]
    }

    private func configuredShare(for server: RemoteServer) -> NetworkShare? {
        let path = normalizedRemotePath(server.remotePath)
        guard path != "/" else { return nil }
        var components = URLComponents()
        components.scheme = server.remoteProtocol.urlScheme
        components.host = server.host
        components.path = path
        guard let url = components.url else { return nil }
        return NetworkShare(name: configuredShareName(path), url: url)
    }

    private func configuredShareName(_ path: String) -> String {
        let firstComponent = path.split(separator: "/", omittingEmptySubsequences: true).first
        return firstComponent.map(String.init) ?? path
    }

    private func normalizedRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
    }

    private func mergeConfiguredShare(from server: RemoteServer, into index: Int) {
        guard let share = configuredShare(for: server) else { return }
        guard hosts[index].shares.contains(where: { $0.url.absoluteString == share.url.absoluteString }) == false else {
            return
        }
        hosts[index].shares.append(share)
        hosts[index].sharesLoaded = true
        hosts[index].shareLoadState = .loaded
    }

    private func applyConfiguredClassification(to index: Int, server: RemoteServer) {
        guard let cls = NetworkDeviceFingerprinter.classifyByName(server.displayName, hostName: server.host) else { return }
        hosts[index].deviceClass = cls
    }

    private func serviceType(for remoteProtocol: RemoteProtocol) -> NetworkServiceType? {
        switch remoteProtocol {
        case .smb:
            return .smb
        case .afp:
            return .afp
        case .sftp, .ftp:
            return nil
        }
    }
}
