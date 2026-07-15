// NetNeighborProvider+VendorLookup.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enriches discovered hosts with online MAC vendor information.

import Foundation

// MARK: - Manufacturer Enrichment
extension NetworkNeighborhoodProvider {
    func runManufacturerLookupPass() {
        let candidates = hosts.compactMap { host -> (NetworkHost.ID, String)? in
            guard host.manufacturer == nil, let mac = host.rawMAC else { return nil }
            return (host.id, mac)
        }
        guard !candidates.isEmpty else { return }
        Task {
            for (hostID, mac) in candidates {
                guard let manufacturer = await MACVendorLookupService.shared.manufacturer(for: mac) else { continue }
                if let index = hosts.firstIndex(where: { $0.id == hostID }) {
                    hosts[index].manufacturer = manufacturer
                    refineDeviceClass(at: index, manufacturer: manufacturer)
                    log.info("[NetworkVendor] '\(hosts[index].name)' → \(manufacturer)")
                }
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }

    // MARK: - Vendor Classification
    private func refineDeviceClass(at index: Int, manufacturer: String) {
        if hosts[index].nodeType == .mobileDevice,
            manufacturer.localizedCaseInsensitiveContains("apple")
        {
            if hosts[index].deviceClass == .unknown { hosts[index].deviceClass = .appleMobile }
            return
        }
        guard hosts[index].deviceClass == .unknown,
            let deviceClass = NetworkDeviceFingerprinter.classifyByName(manufacturer, hostName: "")
        else { return }
        hosts[index].deviceClass = deviceClass
        if deviceClass.isRouter { hosts[index].nodeType = .generic }
    }
}
