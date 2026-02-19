// NetworkHost.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model representing a discovered network host

import Foundation

// MARK: - Network host discovered via Bonjour
public struct NetworkHost: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String           // Human-readable name e.g. "MacBook Pro"
    public let hostName: String       // e.g. "macbook-pro.local"
    public let addresses: [String]    // IP addresses
    public let serviceType: String    // e.g. "_smb._tcp", "_afpovertcp._tcp"

    public init(name: String, hostName: String, addresses: [String] = [], serviceType: String) {
        self.id = UUID()
        self.name = name
        self.hostName = hostName
        self.addresses = addresses
        self.serviceType = serviceType
    }

    // MARK: - SMB URL for this host
    public var smbURL: URL? {
        URL(string: "smb://\(hostName)/")
    }

    // MARK: - AFP URL for this host
    public var afpURL: URL? {
        URL(string: "afp://\(hostName)/")
    }
}
