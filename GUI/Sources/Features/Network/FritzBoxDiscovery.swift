// FritzBoxDiscovery.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Discovers ALL LAN hosts via FritzBox TR-064 UPnP API (no auth required).
//              Shows both active and inactive hosts — inactive shown greyed out.

import Foundation

// MARK: - Host entry from FritzBox DHCP table
struct FritzBoxHost {
    let name: String
    let ip: String
    let mac: String
    let isActive: Bool
    let interfaceType: String   // "802.11" = WiFi, "Ethernet" = wired, "" = unknown
}

// MARK: - FritzBox TR-064 discovery
enum FritzBoxDiscovery {
    private static let upnpURL = "http://fritz.box:49000/upnp/control/hosts"

    // MARK: - Check reachability via SOAP ping
    static func isAvailable() async -> Bool {
        return await hostCount() != nil
    }

    // MARK: - Get count of DHCP entries
    static func hostCount() async -> Int? {
        let body = soapEnvelope(action: "GetHostNumberOfEntries", params: "")
        guard let xml = await postSOAP(body: body, action: "GetHostNumberOfEntries")
        else { return nil }
        return extractInt(xml, tag: "NewHostNumberOfEntries")
    }

    // MARK: - Get ALL hosts (active AND inactive)
    // Inactive = device is off/sleeping but was registered in DHCP
    // We show them so user sees Sascha, Vuduo2 etc. even when they're off
    static func allHosts() async -> [FritzBoxHost] {
        guard let count = await hostCount() else {
            log.warning("[FritzBox] not reachable or no response")
            return []
        }
        log.info("[FritzBox] fetching \(count) DHCP entries")

        var results: [FritzBoxHost] = []
        await withTaskGroup(of: FritzBoxHost?.self) { group in
            for i in 0..<count {
                group.addTask { await fetchHost(index: i) }
            }
            for await host in group {
                if let h = host { results.append(h) }
            }
        }

        // Dedup: prefer active over inactive when same name or same IP
        var byIP   = [String: FritzBoxHost]()
        var byName = [String: FritzBoxHost]()
        for h in results {
            let key = h.name.lowercased()
            // Keep active over inactive; keep first if both same state
            if !h.ip.isEmpty {
                if let existing = byIP[h.ip] {
                    if h.isActive && !existing.isActive { byIP[h.ip] = h }
                } else {
                    byIP[h.ip] = h
                }
            }
            if let existing = byName[key] {
                if h.isActive && !existing.isActive { byName[key] = h }
            } else {
                byName[key] = h
            }
        }
        // Final list: unique by name
        var final = Array(byName.values)
        final.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let summary = final.map { "\($0.name)(\($0.ip),\($0.isActive ? "on" : "off"))" }
        log.info("[FritzBox] hosts: \(summary)")
        return final
    }

    // MARK: - Kept for compatibility
    static func activeHosts() async -> [FritzBoxHost] {
        return await allHosts()
    }

    // MARK: - Fetch single host entry by index
    private static func fetchHost(index: Int) async -> FritzBoxHost? {
        let params = "<NewIndex>\(index)</NewIndex>"
        let body   = soapEnvelope(action: "GetGenericHostEntry", params: params)
        guard let xml = await postSOAP(body: body, action: "GetGenericHostEntry")
        else { return nil }
        guard let name = extractString(xml, tag: "NewHostName"), !name.isEmpty
        else { return nil }
        let ip     = extractString(xml, tag: "NewIPAddress") ?? ""
        let mac    = extractString(xml, tag: "NewMACAddress") ?? ""
        let active = extractString(xml, tag: "NewActive") == "1"
        let itype  = extractString(xml, tag: "NewInterfaceType") ?? ""
        return FritzBoxHost(name: name, ip: ip, mac: mac, isActive: active, interfaceType: itype)
    }

    // MARK: - Build SOAP envelope
    private static func soapEnvelope(action: String, params: String) -> String {
        """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body>
            <u:\(action) xmlns:u="urn:dslforum-org:service:Hosts:1">\(params)</u:\(action)>
          </s:Body>
        </s:Envelope>
        """
    }

    // MARK: - POST SOAP — SOAPAction header is mandatory (without it FritzBox returns 404)
    private static func postSOAP(body: String, action: String) async -> String? {
        guard let url  = URL(string: upnpURL),
              let data = body.data(using: .utf8) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 5.0)
        req.httpMethod = "POST"
        req.httpBody   = data
        req.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("urn:dslforum-org:service:Hosts:1#\(action)", forHTTPHeaderField: "SOAPAction")
        guard let (respData, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return String(data: respData, encoding: .utf8)
    }

    // MARK: - XML helpers
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
