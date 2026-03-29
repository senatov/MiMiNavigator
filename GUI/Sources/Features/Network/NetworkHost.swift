// NetworkHost.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model for a discovered network host and its shares.
//   Covers Bonjour, SMB/AFP/SFTP/FTP, mobile devices, routers, printers,
//   media devices, and post-fingerprint Web UI probing.

import Foundation

// MARK: - Network service type
enum NetworkServiceType: String, CaseIterable, Sendable {
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

    var urlScheme: String {
        switch self {
            case .smb:
                return "smb"
            case .afp:
                return "afp"
            case .sftp:
                return "sftp"
            case .ftp:
                return "ftp"
        }
    }
}

// MARK: - Node type for tree display
enum NetworkNodeType: Sendable {
    case fileServer
    case printer
    case mobileDevice
    case generic

    var displayName: String {
        switch self {
            case .fileServer:
                return "File Server"
            case .printer:
                return "Printer"
            case .mobileDevice:
                return "Mobile"
            case .generic:
                return "Generic"
        }
    }
}

// MARK: - A single share/volume on a host
struct NetworkShare: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    let url: URL

    init(name: String, url: URL) {
        self.id   = UUID()
        self.name = name
        self.url  = url
    }
}

// MARK: - Discovered network host
struct NetworkHost: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var hostName: String
    var port: Int
    let serviceType: NetworkServiceType

    var nodeType: NetworkNodeType
    var deviceClass: NetworkDeviceXT
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
        deviceClass: NetworkDeviceXT = .unknown,
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

    // MARK: - Helpers
    private var hasCustomPort: Bool {
        port != serviceType.defaultPort
    }

    private var normalizedDashedIPv4Name: String? {
        let parts = name.components(separatedBy: "-")
        guard parts.count == 4 else { return nil }
        guard parts.allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false }) else { return nil }
        return parts.joined(separator: ".")
    }

    private var isIPv4HostName: Bool {
        let parts = hostName.components(separatedBy: ".")
        return parts.count == 4 && parts.allSatisfy { Int($0).map { (0...255).contains($0) } ?? false }
    }

    private var isUnusableHostName: Bool {
        hostName.isEmpty || hostName == "(nil)" || hostName.contains("@")
    }

    private var normalizedHostNameOrNil: String? {
        guard !isUnusableHostName else { return nil }
        return hostName
    }

    private var preferredDisplayName: String {
        normalizedDashedIPv4Name ?? name
    }

    private var preferredConnectionHost: String? {
        normalizedHostNameOrNil
    }

    private var preferredWebUIHost: String {
        preferredConnectionHost ?? preferredDisplayName
    }

    // MARK: - Root URL for this host
    var mountURL: URL? {
        guard let mountHost = preferredConnectionHost else { return nil }

        var components = URLComponents()
        components.scheme = serviceType.urlScheme
        components.host = mountHost
        if hasCustomPort {
            components.port = port
        }
        components.path = "/"
        return components.url
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
        preferredDisplayName
    }

    // MARK: - IP address (hostName when it's an IP, else empty)
    var hostIP: String {
        isIPv4HostName ? hostName : ""
    }

    // MARK: - Preferred addressing
    // Display name for UI text (safe, human-readable)
    // Host used for file protocol connections when available
    var effectiveHostName: String {
        preferredConnectionHost ?? preferredDisplayName
    }

    // MARK: - Host used for HTTP/Web UI fallback logic
    var webUIHost: String {
        preferredWebUIHost
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

    // MARK: - Web UI
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
            return URL(string: "http://" + webUIHost + ":631")
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
        return webUIHost
    }
}
