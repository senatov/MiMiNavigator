// NetworkServiceCatalog.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bonjour service groups used by Network Neighborhood discovery.

import Foundation
import NetworkKit

// MARK: - Network service catalog
enum NetworkServiceCatalog {
    nonisolated static let printerTypes: Set<String> = [
        "_ipp._tcp.", "_ipps._tcp.", "_pdl-datastream._tcp.",
        "_printer._tcp.", "_fax-ipp._tcp.", "_scanner._tcp.", "_uscan._tcp.",
    ]
    nonisolated static let mediaTypes: Set<String> = [
        "_airplay._tcp.", "_raop._tcp.", "_googlecast._tcp.",
        "_spotify-connect._tcp.", "_sonos._tcp.",
    ]
    nonisolated static let smartHomeTypes: Set<String> = [
        "_hap._tcp.", "_matter._tcp.", "_matterc._udp.", "_home-assistant._tcp.",
    ]
    nonisolated static let genericTypes: Set<String> = [
        "_http._tcp.", "_https._tcp.", "_workstation._tcp.", "_device-info._tcp.",
    ]
    nonisolated static let mobileType = "_apple-mobdev2._tcp."
    nonisolated static let browseTypes: [String] = {
        NetworkServiceType.allCases.map(\.rawValue)
            + Array(printerTypes)
            + Array(mediaTypes)
            + Array(smartHomeTypes)
            + Array(genericTypes)
            + [mobileType]
    }()

    nonisolated static func isPrinter(_ type: String) -> Bool {
        printerTypes.contains(type)
    }

    nonisolated static func isMedia(_ type: String) -> Bool {
        mediaTypes.contains(type)
    }

    nonisolated static func isGeneric(_ type: String) -> Bool {
        genericTypes.contains(type) || smartHomeTypes.contains(type) || mediaTypes.contains(type)
    }
}
