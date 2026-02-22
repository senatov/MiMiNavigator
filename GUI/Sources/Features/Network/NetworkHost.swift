// NetworkHost.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 21.02.2026 — deviceClass fingerprinting, bonjourServices set
// Refactored: 22.02.2026 — mobileDevice class; isLocalhost flag; fritz/router by name
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model representing a discovered network host (SMB/AFP/Bonjour/Mobile)

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
}

// MARK: - Node type for tree display
enum NetworkNodeType {
    case fileServer
    case printer
    case mobileDevice
    case generic
}

// MARK: - A single share/volume on a host
struct NetworkShare: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL

    init(name: String, url: URL) {
        self.id   = UUID()
        self.name = name
        self.url  = url
    }
}

// MARK: - Hardware device class
enum NetworkDeviceClass {
    case mac
    case windowsPC
    case linuxServer
    case nas
    case router
    case printer
    case iPhone
    case iPad
    case unknown

    var systemIconName: String {
        switch self {
        case .mac:          return "desktopcomputer"
        case .windowsPC:    return "pc"
        case .linuxServer:  return "server.rack"
        case .nas:          return "externaldrive.connected.to.line.below"
        case .router:       return "wifi.router"
        case .printer:      return "printer"
        case .iPhone:       return "iphone"
        case .iPad:         return "ipad"
        case .unknown:      return "network"
        }
    }

    var label: String {
        switch self {
        case .mac:          return "Mac"
        case .windowsPC:    return "PC"
        case .linuxServer:  return "Linux"
        case .nas:          return "NAS"
        case .router:       return "Router"
        case .printer:      return "Printer"
        case .iPhone:       return "iPhone"
        case .iPad:         return "iPad"
        case .unknown:      return ""
        }
    }

    var isExpandable: Bool {
        switch self {
        case .printer, .router, .iPhone, .iPad: return false
        default: return true
        }
    }

    var isRouter: Bool { self == .router }
    var isMobile: Bool { self == .iPhone || self == .iPad }
}

// MARK: - Discovered network host
struct NetworkHost: Identifiable, Hashable {
    let id: UUID
    let name: String
    var hostName: String
    var port: Int
    let serviceType: NetworkServiceType

    var nodeType: NetworkNodeType
    var deviceClass: NetworkDeviceClass
    var shares: [NetworkShare]
    var sharesLoaded: Bool
    var sharesLoading: Bool
    var bonjourServices: Set<String>
    var isLocalhost: Bool           // true = this Mac itself

    // MARK: -
    init(
        name: String,
        hostName: String,
        port: Int,
        serviceType: NetworkServiceType,
        nodeType: NetworkNodeType = .fileServer,
        deviceClass: NetworkDeviceClass = .unknown,
        isLocalhost: Bool = false
    ) {
        self.id             = UUID()
        self.name           = name
        self.hostName       = hostName
        self.port           = port
        self.serviceType    = serviceType
        self.nodeType       = nodeType
        self.deviceClass    = deviceClass
        self.shares         = []
        self.sharesLoaded   = false
        self.sharesLoading  = false
        self.bonjourServices = []
        self.isLocalhost    = isLocalhost
    }

    // MARK: - Root URL for this host
    var mountURL: URL? {
        var c = URLComponents()
        c.scheme = serviceType == .afp ? "afp" : serviceType == .sftp ? "sftp" :
                   serviceType == .ftp  ? "ftp"  : "smb"
        c.host   = hostName
        if port != serviceType.defaultPort { c.port = port }
        c.path   = "/"
        return c.url
    }

    // MARK: - SF Symbol
    var systemIconName: String {
        if deviceClass != .unknown { return deviceClass.systemIconName }
        switch nodeType {
        case .printer:      return "printer"
        case .mobileDevice: return "iphone"
        case .fileServer:
            switch serviceType {
            case .sftp, .ftp: return "terminal"
            default:          return "desktopcomputer"
            }
        case .generic: return "network"
        }
    }

    var isExpandable: Bool {
        if deviceClass != .unknown { return deviceClass.isExpandable }
        return nodeType == .fileServer
    }

    // MARK: - Badge label
    var deviceLabel: String { deviceClass.label }
}
