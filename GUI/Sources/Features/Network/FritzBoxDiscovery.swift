// FritzBoxDiscovery.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Discovers ALL LAN hosts via FritzBox TR-064 UPnP API (no auth required).
//              Shows both active and inactive hosts — inactive shown greyed out.

import Foundation

// MARK: - FritzBox TR-064 discovery
enum FritzBoxDiscovery {
    private static let upnpURLs = [
        "http://fritz.box:49000/upnp/control/hosts",
        "http://192.168.178.1:49000/upnp/control/hosts",
        "http://192.168.1.1:49000/upnp/control/hosts",
        "http://192.168.0.1:49000/upnp/control/hosts"
    ]

    // MARK: - Check reachability via SOAP ping
    @concurrent static func isAvailable() async -> Bool {
        return await hostCount() != nil
    }

    // MARK: - Get count of DHCP entries
    @concurrent static func hostCount() async -> Int? {
        let body = soapEnvelope(action: "GetHostNumberOfEntries", params: "")
        guard let xml = await postSOAP(body: body, action: "GetHostNumberOfEntries") else {
            log.warning("[FritzBox] GetHostNumberOfEntries failed on all known endpoints")
            return nil
        }

        let count = extractInt(xml, tag: "NewHostNumberOfEntries")
        log.info("[FritzBox] hostCount=\(count.map(String.init) ?? "nil")")
        return count
    }

    // MARK: - Get ALL hosts (active AND inactive)
    // Inactive = device is off/sleeping but was registered in DHCP
    // We show them so user sees Sascha, Vuduo2 etc. even when they're off
    @concurrent static func allHosts() async -> [FritzBoxHost] {
        guard let count = await hostCount() else {
            log.warning("[FritzBox] not reachable or no response")
            return []
        }
        log.info("[FritzBox] fetching \(count) DHCP entries")
        var results: [FritzBoxHost] = []
        await withTaskGroup(of: FritzBoxHost?.self) { @concurrent group in
            for i in 0..<count {
                group.addTask { @concurrent in await fetchHost(index: i) }
            }
            for await host in group {
                if let h = host { results.append(h) }
            }
        }

        // Dedup: prefer active over inactive when same name or same IP
        var byIP = [String: FritzBoxHost]()
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
    @concurrent static func activeHosts() async -> [FritzBoxHost] {
        return await allHosts()
    }

    // MARK: - Fetch single host entry by index
    @concurrent private static func fetchHost(index: Int) async -> FritzBoxHost? {
        let params = "<NewIndex>\(index)</NewIndex>"
        let body = soapEnvelope(action: "GetGenericHostEntry", params: params)
        guard let xml = await postSOAP(body: body, action: "GetGenericHostEntry") else {
            log.debug("[FritzBox] host entry \(index) unavailable")
            return nil
        }
        guard let name = extractString(xml, tag: "NewHostName"), !name.isEmpty
        else { return nil }
        let ip = extractString(xml, tag: "NewIPAddress") ?? ""
        let mac = extractString(xml, tag: "NewMACAddress") ?? ""
        let active = extractString(xml, tag: "NewActive") == "1"
        let itype = extractString(xml, tag: "NewInterfaceType") ?? ""
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
    @concurrent private static func postSOAP(body: String, action: String) async -> String? {
        guard let data = body.data(using: .utf8) else { return nil }

        for endpoint in upnpURLs {
            guard let url = URL(string: endpoint) else { continue }

            var req = URLRequest(url: url, timeoutInterval: 5.0)
            req.httpMethod = "POST"
            req.httpBody = data
            req.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.setValue("urn:dslforum-org:service:Hosts:1#\(action)", forHTTPHeaderField: "SOAPAction")

            do {
                let (respData, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else {
                    log.debug("[FritzBox] \(action) endpoint=\(endpoint) returned non-HTTP response")
                    continue
                }

                guard http.statusCode == 200 else {
                    log.debug("[FritzBox] \(action) endpoint=\(endpoint) status=\(http.statusCode)")
                    continue
                }

                if let xml = String(data: respData, encoding: .utf8) {
                    log.debug("[FritzBox] \(action) endpoint=\(endpoint) OK")
                    return xml
                }

                log.debug("[FritzBox] \(action) endpoint=\(endpoint) invalid UTF-8")
            } catch {
                log.debug("[FritzBox] \(action) endpoint=\(endpoint) error=\(error.localizedDescription)")
            }
        }

        return nil
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
