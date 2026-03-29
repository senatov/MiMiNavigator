//
//  FritzBoxHost.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//


import Foundation

// MARK: - Host entry from FritzBox DHCP table
struct FritzBoxHost {
    let name: String
    let ip: String
    let mac: String
    let isActive: Bool
    let interfaceType: String   // "802.11" = WiFi, "Ethernet" = wired, "" = unknown
}