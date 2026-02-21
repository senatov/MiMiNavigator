// NetworkHost.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 20.02.2026 — nodeType + shares for tree-style Network Neighborhood
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model representing a discovered network host (SMB/AFP/Bonjour)

import Foundation

// MARK: - Network service type
enum NetworkServiceType: String, CaseIterable {
    case smb  = "_smb._tcp."
    case afp  = "_afpovertcp._tcp."
    case sftp = "_sftp-ssh._tcp."
    case ftp  = "_ftp._tcp."

    var displayName: String {
        switch self {
        case .smb:  return "SMB"
        case .afp:  return "AFP"
        case .sftp: return "SFTP"
        case .ftp:  return "FTP"
        }
    }

    var defaultPort: Int {
        switch self {
        case .smb:  return 445
        case .afp:  return 548
        case .sftp: return 22
        case .ftp:  return 21
        }
    }

    /// True if this service type provides a browsable file system
    var isFileServer: Bool {
        switch self {
        case .smb, .afp, .sftp, .ftp: return true
        }
    }
}

// MARK: - Node type for tree display
enum NetworkNodeType {
    case fileServer     // expandable — has shares
    case printer        // not expandable — no FS
    case generic        // unknown device, not expandable
}

// MARK: - A single share/volume on a host
struct NetworkShare: Identifiable, Hashable {
    let id: UUID
    let name: String            // Share name e.g. "Public", "homes"
    let url: URL                // smb://host/share or afp://host/share

    init(name: String, url: URL) {
        self.id = UUID()
        self.name = name
        self.url = url
    }
}

// MARK: - Discovered network host
struct NetworkHost: Identifiable, Hashable {
    let id: UUID
    let name: String                        // Bonjour display name
    let hostName: String                    // resolved hostname or IP
    let port: Int
    let serviceType: NetworkServiceType

    // MARK: - Tree state (mutable via provider)
    var nodeType: NetworkNodeType           // determines icon and expand ability
    var shares: [NetworkShare]             // populated on expand
    var sharesLoaded: Bool                 // true after first fetch attempt
    var sharesLoading: Bool                // spinner while fetching

    // MARK: -
    init(
        name: String,
        hostName: String,
        port: Int,
        serviceType: NetworkServiceType,
        nodeType: NetworkNodeType = .fileServer
    ) {
        self.id = UUID()
        self.name = name
        self.hostName = hostName
        self.port = port
        self.serviceType = serviceType
        self.nodeType = nodeType
        self.shares = []
        self.sharesLoaded = false
        self.sharesLoading = false
    }

    /// Root URL for this host: smb://hostname/ or afp://hostname/
    var mountURL: URL? {
        var components = URLComponents()
        components.scheme = serviceType == .afp ? "afp" : "smb"
        components.host = hostName
        if port != serviceType.defaultPort {
            components.port = port
        }
        components.path = "/"
        return components.url
    }

    // MARK: - SF Symbol name for node icon
    var systemIconName: String {
        switch nodeType {
        case .printer:    return "printer"
        case .fileServer:
            switch serviceType {
            case .sftp, .ftp: return "terminal"
            default:          return "desktopcomputer"
            }
        case .generic:    return "network"
        }
    }

    // MARK: - Whether this node can be expanded
    var isExpandable: Bool {
        nodeType == .fileServer
    }
}
