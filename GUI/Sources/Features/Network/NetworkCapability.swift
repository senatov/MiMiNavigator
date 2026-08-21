// NetworkCapability.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: User-visible capabilities inferred from advertised network services.

import Foundation
import NetworkKit

// MARK: - Network capability
enum NetworkCapability: String, CaseIterable, Identifiable, Sendable {
    case fileSharing
    case webInterface
    case printing
    case scanning
    case airPlay
    case googleCast
    case audioPlayback
    case dlna
    case smartHome

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fileSharing: return "File Sharing"
        case .webInterface: return "Web Interface"
        case .printing: return "Printing"
        case .scanning: return "Scanning"
        case .airPlay: return "AirPlay"
        case .googleCast: return "Google Cast"
        case .audioPlayback: return "Network Audio"
        case .dlna: return "UPnP / DLNA"
        case .smartHome: return "HomeKit / Matter"
        }
    }

    var systemImage: String {
        switch self {
        case .fileSharing: return "externaldrive.connected.to.line.below"
        case .webInterface: return "safari"
        case .printing: return "printer"
        case .scanning: return "scanner"
        case .airPlay: return "airplayvideo"
        case .googleCast: return "tv.badge.wifi"
        case .audioPlayback: return "hifispeaker"
        case .dlna: return "play.tv"
        case .smartHome: return "house"
        }
    }
}

// MARK: - Network host capabilities
extension NetworkHost {
    var capabilities: [NetworkCapability] {
        let services = bonjourServices.map { $0.lowercased() }
        var result = Set<NetworkCapability>()
        if services.contains(where: { $0.contains("_smb") || $0.contains("_afpovertcp") || $0.contains("_ftp") || $0.contains("_sftp") }) {
            result.insert(.fileSharing)
        }
        if services.contains(where: { $0.contains("_http") || $0.contains("_https") }) || webUIURL != nil {
            result.insert(.webInterface)
        }
        if services.contains(where: { $0.contains("_ipp") || $0.contains("_printer") || $0.contains("_pdl-datastream") }) {
            result.insert(.printing)
        }
        if services.contains(where: { $0.contains("_scanner") || $0.contains("_uscan") }) {
            result.insert(.scanning)
        }
        if services.contains(where: { $0.contains("_airplay") || $0.contains("_raop") }) {
            result.insert(.airPlay)
        }
        if services.contains(where: { $0.contains("_googlecast") }) {
            result.insert(.googleCast)
        }
        if services.contains(where: { $0.contains("_spotify-connect") || $0.contains("_sonos") }) {
            result.insert(.audioPlayback)
        }
        if services.contains(where: { $0.contains("ssdp") || $0.contains("upnp") || $0.contains("mediarenderer") || $0.contains("mediaserver") }) {
            result.insert(.dlna)
        }
        if services.contains(where: { $0.contains("_hap") || $0.contains("_matter") || $0.contains("_home-assistant") }) {
            result.insert(.smartHome)
        }
        return NetworkCapability.allCases.filter { result.contains($0) }
    }
}
