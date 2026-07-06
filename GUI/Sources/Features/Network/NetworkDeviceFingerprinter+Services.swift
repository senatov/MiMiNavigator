// NetworkDeviceFingerprinter+Services.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Device classification from advertised Bonjour and discovery services.

import Foundation

// MARK: - Service-based device classification
extension NetworkDeviceFingerprinter {
    private struct Candidate {
        let device: NetworkDeviceXT
        let score: Int
    }

    static func classifyByServices(_ serviceTypes: Set<String>) -> NetworkDeviceXT? {
        let types = serviceTypes.map { $0.lowercased() }
        let hasType: (String) -> Bool = { needle in types.contains { $0.contains(needle) } }
        let hasSMB = hasType("_smb._tcp.")
        let hasSFTP = hasType("_sftp-ssh._tcp.")
        let hasFTP = hasType("_ftp._tcp.")
        let hasMedia = hasType("_airplay._tcp.") || hasType("_googlecast._tcp.")
            || hasType("_raop._tcp.") || hasType("_spotify-connect._tcp.") || hasType("_sonos._tcp.")
        let hasUPnP = hasType("_upnp") || hasType("_media") || hasType("ssdp")
        let hasHTTP = hasType("_http._tcp.") || hasType("_https._tcp.")
        let hasPrinter = types.contains {
            $0.contains("_ipp._tcp.") || $0.contains("_ipps._tcp.")
                || $0.contains("_printer._tcp.") || $0.contains("_pdl-datastream._tcp.")
                || $0.contains("_fax-ipp._tcp.") || $0.contains("_scanner._tcp.")
                || $0.contains("_uscan._tcp.")
        }
        var candidates: [Candidate] = []
        if types.contains(where: { $0.contains("mobdev") }) { candidates.append(.init(device: .iPhone, score: 100)) }
        if hasPrinter { candidates.append(.init(device: .printer, score: 100)) }
        if hasSMB && hasSFTP { candidates.append(.init(device: .mac, score: 95)) }
        if (hasSFTP || hasFTP) && !hasSMB { candidates.append(.init(device: .linuxServer, score: 90)) }
        if hasMedia { candidates.append(.init(device: .mediaBox, score: 70)) }
        if hasUPnP && hasHTTP { candidates.append(.init(device: .mediaBox, score: 55)) }
        return candidates.sorted { lhs, rhs in
            if lhs.score == rhs.score { return String(describing: lhs.device) < String(describing: rhs.device) }
            return lhs.score > rhs.score
        }.first?.device
    }
}
