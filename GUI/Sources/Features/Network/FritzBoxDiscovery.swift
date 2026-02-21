// FritzBoxDiscovery.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Discovers all LAN hosts via FritzBox TR-064 UPnP API (no auth required).
//              Falls back gracefully if no FritzBox present.

import Foundation

// MARK: - Host entry from FritzBox DHCP table
struct FritzBoxHost {
    let name: String
    let ip: String
    let isActive: Bool
}

// MARK: - FritzBox TR-064 discovery
enum FritzBoxDiscovery {

    private static let fritzIP   = "192.168.178.1"
    private static let upnpURL   = "http://192.168.178.1:49000/upnp/control/hosts"
    private static let infoURL   = "http://192.168.178.1/jason_boxinfo.xml"

    // MARK: - Check if FritzBox is reachable
    static func isAvailable() async -> Bool {
        guard let url = URL(string: infoURL) else { return false }
        var req = URLRequest(url: url, timeoutInterval: 2.0)
        req.httpMethod = "HEAD"
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    // MARK: - Get count of DHCP entries
    static func hostCount() async -> Int? {
        let body = soapEnvelope(action: "GetHostNumberOfEntries", service: "Hosts:1", params: "")
        guard let xml = await postSOAP(body: body) else { return nil }
        return extractInt(xml, tag: "NewHostNumberOfEntries")
    }

    // MARK: - Get all active hosts with real names
    static func activeHosts() async -> [FritzBoxHost] {
        guard let count = await hostCount() else {
            log.warning("[FritzBox] not reachable or no response")
            return []
        }
        log.info("[FritzBox] fetching \(count) DHCP entries")
        var results: [FritzBoxHost] = []
        // Fetch all entries concurrently in batches of 10
        await withTaskGroup(of: FritzBoxHost?.self) { group in
            for i in 0..<count {
                group.addTask { await fetchHost(index: i) }
            }
            for await host in group {
                if let h = host, h.isActive { results.append(h) }
            }
        }
        // Deduplicate by name (FritzBox can have multiple IPs for same host)
        var seen = Set<String>()
        results = results.filter { seen.insert($0.name.lowercased()).inserted }
        results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        log.info("[FritzBox] active hosts: \(results.map { "\($0.name)(\($0.ip))" })")
        return results
    }

    // MARK: - Fetch single host entry by index
    private static func fetchHost(index: Int) async -> FritzBoxHost? {
        let params = "<NewIndex>\(index)</NewIndex>"
        let body   = soapEnvelope(action: "GetGenericHostEntry", service: "Hosts:1", params: params)
        guard let xml = await postSOAP(body: body) else { return nil }
        guard let name   = extractString(xml, tag: "NewHostName"), !name.isEmpty,
              let active = extractString(xml, tag: "NewActive")
        else { return nil }
        let ip = extractString(xml, tag: "NewIPAddress") ?? ""
        return FritzBoxHost(name: name, ip: ip, isActive: active == "1")
    }

    // MARK: - SOAP helper
    private static func soapEnvelope(action: String, service: String, params: String) -> String {
        """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body>
            <u:\(action) xmlns:u="urn:dslforum-org:service:\(service)">\(params)</u:\(action)>
          </s:Body>
        </s:Envelope>
        """
    }

    private static func postSOAP(body: String) async -> String? {
        guard let url = URL(string: upnpURL),
              let data = body.data(using: .utf8) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 3.0)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        guard let (respData, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return String(data: respData, encoding: .utf8)
    }

    private static func extractString(_ xml: String, tag: String) -> String? {
        guard let r = xml.range(of: "<\(tag)>"),
              let e = xml.range(of: "</\(tag)>", range: r.upperBound..<xml.endIndex)
        else { return nil }
        return String(xml[r.upperBound..<e.lowerBound])
    }

    private static func extractInt(_ xml: String, tag: String) -> Int? {
        extractString(xml, tag: tag).flatMap { Int($0) }
    }
}
