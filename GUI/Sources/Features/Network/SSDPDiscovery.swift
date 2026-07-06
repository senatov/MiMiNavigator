// SSDPDiscovery.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Passive UPnP and DLNA discovery using a bounded SSDP multicast query.

import Darwin
import Foundation

// MARK: - SSDP device
struct SSDPDevice: Sendable {
    let name: String
    let address: String
    let port: Int
    let services: Set<String>
    let deviceClass: NetworkDeviceXT
}

// MARK: - SSDP discovery
enum SSDPDiscovery {
    private struct Response: Sendable {
        let location: URL
        let service: String
        let server: String
    }

    private struct Description: Sendable {
        let friendlyName: String?
        let modelName: String?
        let manufacturer: String?
        let deviceType: String?
    }

    private static let multicastAddress = "239.255.255.250"
    private static let multicastPort: UInt16 = 1900
    private static let receiveTimeoutSeconds = 3

    // MARK: - Discover visible UPnP devices
    @concurrent static func discover() async -> [SSDPDevice] {
        let responses = await Task.detached(priority: .utility) { collectResponses() }.value
        guard !responses.isEmpty else {
            log.debug("[SSDP] no responses")
            return []
        }
        var devices: [SSDPDevice] = []
        await withTaskGroup(of: SSDPDevice?.self) { group in
            for response in responses {
                group.addTask { await makeDevice(from: response) }
            }
            for await device in group {
                if let device { devices.append(device) }
            }
        }
        let merged = merge(devices)
        log.info("[SSDP] discovered \(merged.count) devices from \(responses.count) responses")
        return merged
    }

    // MARK: - Collect UDP responses
    nonisolated private static func collectResponses() -> [Response] {
        let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else {
            log.warning("[SSDP] socket creation failed errno=\(errno)")
            return []
        }
        defer { Darwin.close(descriptor) }
        var timeout = timeval(tv_sec: receiveTimeoutSeconds, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = multicastPort.bigEndian
        inet_pton(AF_INET, multicastAddress, &destination.sin_addr)
        let request = "M-SEARCH * HTTP/1.1\r\nHOST: \(multicastAddress):\(multicastPort)\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: ssdp:all\r\n\r\n"
        let sent = request.utf8CString.withUnsafeBytes { bytes in
            withUnsafePointer(to: &destination) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    Darwin.sendto(descriptor, bytes.baseAddress, bytes.count - 1, 0, address, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else {
            log.warning("[SSDP] multicast send failed errno=\(errno)")
            return []
        }
        var responses: [Response] = []
        var buffer = [UInt8](repeating: 0, count: 65_535)
        while true {
            let count = Darwin.recv(descriptor, &buffer, buffer.count, 0)
            guard count > 0 else { break }
            let payload = String(decoding: buffer.prefix(count), as: UTF8.self)
            if let response = parseResponse(payload) { responses.append(response) }
        }
        return uniqueResponses(responses)
    }

    // MARK: - Parse SSDP headers
    nonisolated private static func parseResponse(_ payload: String) -> Response? {
        var headers: [String: String] = [:]
        for line in payload.components(separatedBy: "\r\n").dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        guard let rawLocation = headers["location"], let location = URL(string: rawLocation) else { return nil }
        let service = headers["st"] ?? headers["nt"] ?? "upnp"
        return Response(location: location, service: service, server: headers["server"] ?? "")
    }

    nonisolated private static func uniqueResponses(_ responses: [Response]) -> [Response] {
        var unique: [String: Response] = [:]
        for response in responses {
            let key = response.location.absoluteString + "|" + response.service
            unique[key] = response
        }
        return Array(unique.values)
    }

    // MARK: - Fetch public UPnP description
    private static func makeDevice(from response: Response) async -> SSDPDevice? {
        guard let host = response.location.host else { return nil }
        var request = URLRequest(url: response.location, timeoutInterval: 3)
        request.httpMethod = "GET"
        let description = try? await fetchDescription(request)
        let identity = [description?.friendlyName, description?.modelName, description?.manufacturer, response.server]
            .compactMap { $0 }.joined(separator: " ")
        let name = description?.friendlyName ?? description?.modelName ?? host
        let descriptor = [identity, description?.deviceType, response.service].compactMap { $0 }.joined(separator: " ")
        return SSDPDevice(
            name: name,
            address: host,
            port: response.location.port ?? 80,
            services: ["ssdp", response.service],
            deviceClass: classify(descriptor)
        )
    }

    private static func fetchDescription(_ request: URLRequest) async throws -> Description {
        let (data, _) = try await URLSession.shared.data(for: request)
        let document = try XMLDocument(data: data)
        return Description(
            friendlyName: value("friendlyName", in: document),
            modelName: value("modelName", in: document),
            manufacturer: value("manufacturer", in: document),
            deviceType: value("deviceType", in: document)
        )
    }

    private static func value(_ localName: String, in document: XMLDocument) -> String? {
        try? document.nodes(forXPath: "//*[local-name()='\(localName)']").first?.stringValue
    }

    nonisolated private static func classify(_ descriptor: String) -> NetworkDeviceXT {
        let value = descriptor.lowercased()
        if value.contains("internetgatewaydevice") || value.contains("wanconnectiondevice") { return .router }
        if value.contains("camera") || value.contains("onvif") { return .camera }
        if value.contains("printer") || value.contains("scanner") { return .printer }
        if value.contains("tv") || value.contains("mediarenderer") { return .smartTV }
        if value.contains("mediaserver") || value.contains("dlna") { return .mediaBox }
        if value.contains("playstation") || value.contains("xbox") { return .gameConsole }
        return NetworkDeviceFingerprinter.classifyByName(descriptor, hostName: "") ?? .unknown
    }

    nonisolated private static func merge(_ devices: [SSDPDevice]) -> [SSDPDevice] {
        var merged: [String: SSDPDevice] = [:]
        for device in devices {
            guard let existing = merged[device.address] else {
                merged[device.address] = device
                continue
            }
            merged[device.address] = SSDPDevice(
                name: existing.name == existing.address ? device.name : existing.name,
                address: existing.address,
                port: existing.port,
                services: existing.services.union(device.services),
                deviceClass: existing.deviceClass == .unknown ? device.deviceClass : existing.deviceClass
            )
        }
        return Array(merged.values)
    }
}
