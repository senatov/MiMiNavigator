// EncryptedArchiveCheck.swift
// MiMiNavigator
//
// Created by Claude on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Lightweight encrypted archive detection for icon display.
//   ZIP: reads 8 bytes from Local File Header (bit 0 of General Purpose Flag).
//   Other formats: not checked (would require ArchiveKit dependency).
//   Results cached via NSCache — zero repeated I/O cost.

import FileModelKit
import Foundation

// MARK: - EncryptedArchiveCheck
enum EncryptedArchiveCheck {
    // MARK: - Cache (NSCache is internally thread-safe)
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSNumber>()
    // MARK: - Public API
    /// Returns true if archive is encrypted. Currently supports ZIP only.
    /// Returns false for non-ZIP archives (not nil — safe for icon logic).
    static func isEncrypted(url: URL) -> Bool {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached.boolValue
        }
        let result = checkZip(url: url)
        cache.setObject(NSNumber(value: result), forKey: key)
        return result
    }
    // MARK: - ZIP Check
    /// Reads PK signature + General Purpose Bit Flag. Bit 0 = encrypted.
    private static func checkZip(url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "zip" else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 8), data.count >= 8 else { return false }
        // Verify PK\x03\x04 signature
        guard data[0] == 0x50, data[1] == 0x4B, data[2] == 0x03, data[3] == 0x04 else { return false }
        // General Purpose Bit Flag at offset 6 (little-endian)
        let flags = UInt16(data[6]) | (UInt16(data[7]) << 8)
        return (flags & 0x0001) != 0
    }
}
