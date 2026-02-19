// NetworkNeighborhoodProvider.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Provides discovered hosts as a flat list for virtual directory display

import AppKit
import Foundation

// MARK: - Protocol for the panel to consume network hosts
public protocol NetworkHostConsumer: AnyObject {
    func didUpdateHosts(_ hosts: [NetworkHost])
}

// MARK: - Bridges BonjourDiscovery → panel-consumable model
@MainActor
public final class NetworkNeighborhoodProvider: ObservableObject {

    public static let shared = NetworkNeighborhoodProvider()

    @Published public private(set) var hosts: [NetworkHost] = []
    @Published public private(set) var isScanning: Bool = false

    private let discovery = BonjourDiscovery()
    private var cancellable: Any?

    private init() {
        // Observe discovery changes
        cancellable = discovery.$hosts.assign(to: \.hosts, on: self)
    }

    // MARK: - Start / stop
    public func startScan() {
        isScanning = true
        discovery.startDiscovery()
        // Auto-stop after 10s to save battery
        Task {
            try? await Task.sleep(for: .seconds(10))
            await MainActor.run {
                discovery.stopDiscovery()
                isScanning = false
            }
        }
    }

    public func stopScan() {
        discovery.stopDiscovery()
        isScanning = false
    }

    // MARK: - Open host in Finder (sandbox-safe fallback)
    public func openInFinder(_ host: NetworkHost) {
        guard let url = host.smbURL ?? host.afpURL else { return }
        NSWorkspace.shared.open(url)
    }
}
