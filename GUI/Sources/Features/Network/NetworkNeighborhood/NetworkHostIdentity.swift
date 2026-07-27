// NetworkHostIdentity.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared host identity normalization for merging discovery sources.

import Foundation

// MARK: - Network Host Identity
enum NetworkHostIdentity {
    // MARK: - Identity Keys
    static func keys(name: String, hostName: String) -> Set<String> {
        Set([normalized(name), normalized(hostName)].filter { !$0.isEmpty })
    }

    // MARK: - Host Match
    static func matches(_ host: NetworkHost, name: String, hostName: String) -> Bool {
        !keys(name: host.name, hostName: host.hostName)
            .isDisjoint(with: keys(name: name, hostName: hostName))
    }

    // MARK: - Normalize
    static func normalized(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if result.hasSuffix(".") { result.removeLast() }
        for suffix in ["._smb._tcp.local", "._afp._tcp.local", ".local", ".fritz.box"] {
            if result.hasSuffix(suffix) {
                result.removeLast(suffix.count)
                break
            }
        }
        return result.replacingOccurrences(of: ".", with: "-")
    }
}
