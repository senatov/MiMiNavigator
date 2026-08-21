// NetNeighborProvider+DiscoveryMerge.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Merges router and SSDP discovery results into Network Neighborhood hosts.

import Foundation
import NetworkKit

// MARK: - Discovery result merging
extension NetworkNeighborhoodProvider {
    // MARK: - Merge SSDP devices
    func mergeSSDPDevices(_ devices: [SSDPDevice]) {
        for device in devices where !isLocalhostIP(device.address) {
            if let index = hosts.firstIndex(where: {
                NetworkHostIdentity.matches($0, name: device.name, hostName: device.address)
            }) {
                hosts[index].bonjourServices.formUnion(device.services)
                if hosts[index].deviceClass == .unknown { hosts[index].deviceClass = device.deviceClass }
                continue
            }
            addResolvedHost(
                name: device.name,
                hostName: device.address,
                port: device.port,
                serviceType: nil,
                isPrinter: device.deviceClass == .printer,
                bonjourType: device.services.sorted().joined(separator: ","),
                isGeneric: true
            )
            if let index = hosts.firstIndex(where: { $0.hostName == device.address }) {
                hosts[index].bonjourServices.formUnion(device.services)
                hosts[index].deviceClass = device.deviceClass
            }
        }
    }

    // MARK: - Merge FritzBox DHCP host list
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

    private func buildHostIPIndex() -> [String: Int] {
        var ipToIdx: [String: Int] = [:]
        for (index, host) in hosts.enumerated() where !host.hostName.isEmpty && !host.hostName.contains("@") {
            ipToIdx[host.hostName] = index
            let stripped = host.hostName
                .replacingOccurrences(of: ".local.", with: "")
                .replacingOccurrences(of: ".local", with: "")
            if stripped != host.hostName { ipToIdx[stripped] = index }
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
        let isFritzMobile = isLikelyMobileFritzHostName(fritzHost.name.lowercased())
        if let index = ipToIdx[fritzHost.ip] { return index }
        return hosts.firstIndex { host in
            if NetworkHostIdentity.matches(host, name: fritzHost.name, hostName: fritzHost.ip) { return true }
            return isFritzMobile && isMobilePlaceholderHostName(host.name)
        }
    }

    private func updateExistingHost(at index: Int, with fritzHost: FritzBoxHost) {
        if hosts[index].hostName.contains("@") || hosts[index].hostName.isEmpty {
            hosts[index].hostName = fritzHost.ip
            log.debug("[FritzBox] updated IP \(hosts[index].name) → \(fritzHost.ip)")
        }
        if hosts[index].rawMAC == nil && !fritzHost.mac.isEmpty { hosts[index].rawMAC = fritzHost.mac }
        if !fritzHost.isActive { hosts[index].isOffline = true }
        let existingName = hosts[index].name
        if isMobilePlaceholderHostName(existingName), !fritzHost.name.isEmpty {
            hosts[index].name = fritzHost.name
            if hosts[index].deviceClass == .appleMobile,
                let refinedClass = NetworkDeviceFingerprinter.classifyByName(fritzHost.name, hostName: fritzHost.ip),
                refinedClass.isMobile
            {
                hosts[index].deviceClass = refinedClass
            }
            log.info("[FritzBox] renamed '\(existingName)' → '\(fritzHost.name)' (\(fritzHost.ip))")
        }
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

    private func isLikelyMobileFritzHostName(_ name: String) -> Bool {
        name == "ipad" || name.hasPrefix("iphone") || name.contains("-iphone")
    }

    private func isMobilePlaceholderHostName(_ name: String) -> Bool {
        let value = name.lowercased()
        return value.hasPrefix("apple device") || value.hasPrefix("iphone / ipad")
            || value.hasPrefix("iphone (") || value.hasPrefix("ipad (")
    }
}
