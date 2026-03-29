// NetworkDeviceXT.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Network device kind for host presentation.
//   Defines icon, short label, and expandability rules.

import Foundation


// MARK: - Hardware device class

enum NetworkDeviceXT: Sendable, CaseIterable {
    case mac
    case windowsPC
    case linuxServer
    case nas
    case router
    case printer
    case iPhone
    case iPad
    case mediaBox      // Enigma2 / OpenPLi / Kodi / HTPC — web UI only, no SMB
    case smartTV
    case repeater
    case networkSwitch
    case camera
    case gameConsole
    case androidPhone
    case androidTablet
    case unknown

    // MARK: - Device Groups
    var isRouter: Bool {
        self == .router
    }

    var isMobile: Bool {
        self == .iPhone
            || self == .iPad
            || self == .androidPhone
            || self == .androidTablet
    }

    var isComputer: Bool {
        switch self {
            case .mac, .windowsPC, .linuxServer:
                return true
            default:
                return false
        }
    }

    var isStorage: Bool {
        self == .nas
    }

    var isMediaDevice: Bool {
        self == .mediaBox
            || self == .smartTV
            || self == .gameConsole
    }

    var isInfrastructure: Bool {
        self == .router
            || self == .repeater
            || self == .networkSwitch
            || self == .printer
    }

    var isIoT: Bool {
        self == .camera || self == .printer
    }

    // MARK: - Presentation
    var systemIconName: String {
        switch self {
            case .mac:
                return "desktopcomputer"
            case .windowsPC:
                return "pc"
            case .linuxServer:
                return "server.rack"
            case .nas:
                return "externaldrive.connected.to.line.below"
            case .router:
                return "wifi.router"
            case .printer:
                return "printer"
            case .iPhone:
                return "iphone"
            case .iPad:
                return "ipad"
            case .mediaBox:
                return "tv"
            case .smartTV:
                return "tv.fill"
            case .repeater:
                return "wifi"
            case .networkSwitch:
                return "point.3.connected.trianglepath.dotted"
            case .camera:
                return "video"
            case .gameConsole:
                return "gamecontroller"
            case .androidPhone:
                return "smartphone"
            case .androidTablet:
                return "ipad.landscape"
            case .unknown:
                return "network"
        }
    }

    var label: String {
        switch self {
            case .mac:
                return "Mac"
            case .windowsPC:
                return "PC"
            case .linuxServer:
                return "Linux"
            case .nas:
                return "NAS"
            case .router:
                return "Router"
            case .printer:
                return "Printer"
            case .iPhone:
                return "iPhone"
            case .iPad:
                return "iPad"
            case .mediaBox:
                return "Media"
            case .smartTV:
                return "TV"
            case .repeater:
                return "Repeater"
            case .networkSwitch:
                return "Switch"
            case .camera:
                return "Camera"
            case .gameConsole:
                return "Console"
            case .androidPhone:
                return "Android"
            case .androidTablet:
                return "Android"
            case .unknown:
                return ""
        }
    }

    // MARK: - Behavior
    var isExpandable: Bool {
        switch self {
            case .printer, .router, .repeater, .networkSwitch, .camera, .iPhone, .iPad, .androidPhone, .androidTablet, .mediaBox, .smartTV, .gameConsole:
                return false
            default:
                return true
        }
    }
}
