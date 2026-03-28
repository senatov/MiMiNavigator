// NetworkDeviceClass.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Hardware device class for network hosts — icon, label, expandability.
//   Extracted from NetworkHost.swift for single responsibility.

import Foundation


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
