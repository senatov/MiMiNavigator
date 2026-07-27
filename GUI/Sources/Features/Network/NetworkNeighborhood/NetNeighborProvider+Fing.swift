// NetNeighborProvider+Fing.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Merges Fing Local API device recognition into Network Neighborhood.

import Foundation

// MARK: - Fing Device Merge
extension NetworkNeighborhoodProvider {
    func mergeFingDevices(_ devices: [FingDevice]) {
        for device in devices where device.state.uppercased() == "UP" {
            guard let ip = device.ip.first(where: { !$0.isEmpty }), !isLocalhostIP(ip) else { continue }
            let normalizedMAC = normalizedMACAddress(device.mac)
            let index = matchingFingHostIndex(device: device, ip: ip, normalizedMAC: normalizedMAC)
            if let index {
                updateFingHost(at: index, device: device, ip: ip, normalizedMAC: normalizedMAC)
            } else {
                appendFingHost(device, ip: ip, normalizedMAC: normalizedMAC)
            }
        }
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[Fing] merged \(devices.count) recognized devices")
    }

    // MARK: - Find Existing Host
    private func matchingFingHostIndex(device: FingDevice, ip: String, normalizedMAC: String?) -> Int? {
        if let normalizedMAC,
            let index = hosts.firstIndex(where: { normalizedMACAddress($0.rawMAC ?? "") == normalizedMAC })
        {
            return index
        }
        let name = device.name ?? ""
        return hosts.firstIndex {
            $0.hostIP == ip || NetworkHostIdentity.matches($0, name: name, hostName: ip)
        }
    }

    // MARK: - Update Host
    private func updateFingHost(at index: Int, device: FingDevice, ip: String, normalizedMAC: String?) {
        if hosts[index].hostName.isEmpty || hosts[index].hostName == "(nil)" || hosts[index].hostName.contains("@") {
            hosts[index].hostName = ip
        }
        if let normalizedMAC { hosts[index].rawMAC = normalizedMAC }
        if let make = nonempty(device.make) { hosts[index].manufacturer = make }
        if let model = nonempty(device.model) { hosts[index].modelName = model }
        if let name = nonempty(device.name), shouldReplaceName(hosts[index].name) { hosts[index].name = name }
        let deviceClass = fingDeviceClass(device)
        if deviceClass != .unknown {
            hosts[index].deviceClass = deviceClass
            applyNodeType(deviceClass, at: index)
        }
    }

    // MARK: - Append Host
    private func appendFingHost(_ device: FingDevice, ip: String, normalizedMAC: String?) {
        let name = nonempty(device.name) ?? nonempty(device.model) ?? ip
        addResolvedHost(
            name: name,
            hostName: ip,
            port: 0,
            serviceType: nil,
            isPrinter: fingDeviceClass(device) == .printer,
            isGeneric: true,
            fritzMAC: normalizedMAC
        )
        guard let index = hosts.firstIndex(where: { $0.hostName == ip }) else { return }
        updateFingHost(at: index, device: device, ip: ip, normalizedMAC: normalizedMAC)
    }

    // MARK: - Device Classification
    private func fingDeviceClass(_ device: FingDevice) -> NetworkDeviceXT {
        let type = device.type?.lowercased() ?? ""
        if type.contains("ipad") || type.contains("tablet") && (device.make?.lowercased().contains("apple") == true) { return .iPad }
        if type.contains("iphone") { return .iPhone }
        if type.contains("android") && type.contains("tablet") { return .androidTablet }
        if type.contains("android") || type.contains("smartphone") || type == "phone" { return .androidPhone }
        if type.contains("mac") { return .mac }
        if type.contains("windows") || type == "pc" { return .windowsPC }
        if type.contains("linux") || type.contains("server") { return .linuxServer }
        if type.contains("router") || type.contains("gateway") { return .router }
        if type.contains("repeater") || type.contains("extender") { return .repeater }
        if type.contains("switch") { return .networkSwitch }
        if type.contains("printer") { return .printer }
        if type.contains("nas") || type.contains("storage") { return .nas }
        if type.contains("tv") { return .smartTV }
        if type.contains("stream") || type.contains("media") || type.contains("dongle") { return .mediaBox }
        if type.contains("camera") { return .camera }
        if type.contains("console") || type.contains("gaming") { return .gameConsole }
        let description = [device.name, device.type, device.make, device.model].compactMap { $0 }.joined(separator: " ")
        return NetworkDeviceFingerprinter.classifyByName(description, hostName: "") ?? .unknown
    }

    private func applyNodeType(_ deviceClass: NetworkDeviceXT, at index: Int) {
        if deviceClass.isMobile { hosts[index].nodeType = .mobileDevice }
        else if deviceClass == .printer { hosts[index].nodeType = .printer }
        else if deviceClass.isRouter || deviceClass.isInfrastructure || deviceClass.isMediaDevice || deviceClass.isIoT {
            hosts[index].nodeType = .generic
        } else if deviceClass.isComputer || deviceClass.isStorage { hosts[index].nodeType = .fileServer }
    }

    private func shouldReplaceName(_ value: String) -> Bool {
        let name = value.lowercased()
        let parts = name.split(separator: ".")
        let isIPv4 = parts.count == 4 && parts.allSatisfy { Int($0).map { (0...255).contains($0) } ?? false }
        return name.hasPrefix("apple device") || name.hasPrefix("iphone / ipad") || isIPv4
    }

    private func normalizedMACAddress(_ value: String) -> String? {
        let hex = value.filter(\.isHexDigit).uppercased()
        guard hex.count == 12 else { return nil }
        return stride(from: 0, to: 12, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return String(hex[start..<hex.index(start, offsetBy: 2)])
        }.joined(separator: ":")
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
