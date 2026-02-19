// NetworkHost.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model representing a discovered network host (SMB/AFP/Bonjour)

import Foundation

// MARK: - Network service type
enum NetworkServiceType: String, CaseIterable {
    case smb = "_smb._tcp."
    case afp = "_afp._tcp."
    case sftp = "_sftp-ssh._tcp."
    case ftp = "_ftp._tcp."

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
}

// MARK: - Discovered network host
struct NetworkHost: Identifiable, Hashable {
    let id: UUID
    let name: String               // Bonjour service name / display name
    let hostName: String           // resolved hostname or IP
    let port: Int
    let serviceType: NetworkServiceType

    // MARK: -
    init(name: String, hostName: String, port: Int, serviceType: NetworkServiceType) {
        self.id = UUID()
        self.name = name
        self.hostName = hostName
        self.port = port
        self.serviceType = serviceType
    }

    /// SMB URL for mounting: smb://hostname/
    var mountURL: URL? {
        var components = URLComponents()
        components.scheme = serviceType == .afp ? "afp" : "smb"
        components.host = hostName
        if port != serviceType.defaultPort {
            components.port = port
        }
        return components.url
    }

    /// URL for Finder open
    var finderURL: URL? { mountURL }
}
