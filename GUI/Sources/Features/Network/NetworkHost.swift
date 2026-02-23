// NetworkHost.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 21.02.2026 — deviceClass fingerprinting, bonjourServices set
// Refactored: 22.02.2026 — mobileDevice class; isLocalhost flag; fritz/router by name
// Refactored: 23.02.2026 — probedWebURL field; mediaBox device class
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model representing a discovered network host (SMB/AFP/Bonjour/Mobile/MediaBox).
//   NetworkDeviceClass: mac/windowsPC/linuxServer/nas/router/printer/iPhone/iPad/mediaBox/unknown
//   mediaBox: Enigma2/OpenPLi/Kodi — isExpandable=false, no SMB, web UI only
//   probedWebURL: first responding HTTP port found by WebUIProber (async, post-fingerprint)

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
    var name: String
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
    case mediaBox      // Enigma2 / OpenPLi / Kodi / HTPC — web UI only, no SMB
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
        case .mediaBox:     return "tv"
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
        case .mediaBox:     return "Media"
        case .unknown:      return ""
        }
    }

    var isExpandable: Bool {
        switch self {
        case .printer, .router, .iPhone, .iPad, .mediaBox: return false
        default: return true
        }
    }

    var isRouter: Bool { self == .router }
    var isMobile: Bool { self == .iPhone || self == .iPad }
}

// MARK: - Discovered network host
struct NetworkHost: Identifiable, Hashable {
    let id: UUID
    var name: String
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
    var rawMAC: String?             // MAC address if known (for mobile devices after rename)
    var isOffline: Bool             // true = FritzBox knows device but it's currently off/sleeping
    var probedWebURL: URL?          // first responding web UI port found by WebUIProber

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
        self.rawMAC         = nil
        self.isOffline      = false
        self.probedWebURL   = nil
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

    // MARK: - Human display name: 192-168-178-1 -> 192.168.178.1
    var hostDisplayName: String {
        let parts = name.components(separatedBy: "-")
        if parts.count == 4, parts.allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false }) {
            return parts.joined(separator: ".")
        }
        return name
    }

    // MARK: - IP address (hostName when it's an IP, else empty)
    var hostIP: String {
        // hostName is IP if it's all digits and dots
        let parts = hostName.components(separatedBy: ".")
        if parts.count == 4 && parts.allSatisfy({ Int($0) != nil }) { return hostName }
        return ""
    }

    // MARK: - MAC address from Bonjour _apple-mobdev2 name (AA:BB:CC:DD:EE:FF@ip)
    var macAddress: String? {
        // Prefer explicitly stored MAC (after rename from Apple Device → real name)
        if let raw = rawMAC { return raw.uppercased() }
        // Extract from name if it still contains MAC@addr format
        guard let atIdx = name.firstIndex(of: "@") else { return nil }
        let candidate = String(name[name.startIndex..<atIdx])
        let octets = candidate.components(separatedBy: ":")
        guard octets.count == 6, octets.allSatisfy({ $0.count == 2 }) else { return nil }
        return candidate.uppercased()
    }

    // MARK: - Web UI URL
    // Priority: probed URL (any device, async) > static known URL (router/printer)
    var webUIURL: URL? {
        if let probed = probedWebURL { return probed }
        return staticWebUIURL
    }

    // MARK: - Static web UI URL (known without probing)
    var staticWebUIURL: URL? {
        switch deviceClass {
        case .router:
            return URL(string: "http://" + routerDomain)
        case .printer:
            let h = !hostName.isEmpty && hostName != "(nil)" && !hostName.contains("@")
                ? hostName : hostDisplayName
            return URL(string: "http://" + h + ":631")
        default: return nil
        }
    }

    // MARK: - Router domain by vendor (matches Info.plist NSExceptionDomains)
    private var routerDomain: String {
        let n = name.lowercased()
        // Fritz!Box (AVM, Germany)
        if n.contains("fritz") { return "fritz.box" }
        // TP-Link
        if n.contains("tplink") || n.contains("tp-link") { return "tplinkwifi.net" }
        // Netgear
        if n.contains("netgear") || n.contains("readynas") { return "routerlogin.net" }
        // D-Link
        if n.contains("dlink") || n.contains("d-link") { return "dlinkrouter.local" }
        // Asus
        if n.contains("asus") || n.contains("rt-") { return "router.asus.com" }
        // Linksys
        if n.contains("linksys") { return "myrouter.local" }
        // Fallback to IP address
        return hostDisplayName
    }
}
