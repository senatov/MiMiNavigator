// RemoteTransferNameResolver.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation

// MARK: - Remote Transfer Name Resolver
enum RemoteTransferNameResolver {
    static func uniqueName(_ name: String, isDirectory: Bool, existingNames: Set<String>) -> String {
        guard existingNames.contains(name) else { return name }
        let base = isDirectory ? name : (name as NSString).deletingPathExtension
        let ext = isDirectory ? "" : (name as NSString).pathExtension
        for counter in 2..<10_000 {
            let candidate = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            if !existingNames.contains(candidate) { return candidate }
        }
        return "\(base) (\(UUID().uuidString))\(ext.isEmpty ? "" : ".\(ext)")"
    }
}
