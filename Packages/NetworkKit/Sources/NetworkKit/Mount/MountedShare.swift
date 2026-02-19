// MountedShare.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model for a mounted network share

import Foundation

// MARK: - A network share that has been (or can be) mounted
public struct MountedShare: Identifiable, Sendable {
    public let id: UUID
    public let host: NetworkHost
    public let shareName: String
    public let mountURL: URL         // local /Volumes/sharename path after mounting

    public init(host: NetworkHost, shareName: String, mountURL: URL) {
        self.id = UUID()
        self.host = host
        self.shareName = shareName
        self.mountURL = mountURL
    }
}
