// EncryptedArchiveCheck.swift
// MiMiNavigator
//
// Created by Claude on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Encrypted archive detection for icon display.
//   ZIP: reads 8 bytes from Local File Header (bit 0 of General Purpose Flag).
//   7z:  reads 32 bytes — if header starts with 7z signature, checks
//         NID_Header (byte at offset 6) and encoded header flags.
//   RAR: reads 14 bytes — checks encryption flag in archive header.
//   All checks are pure file reads, NO shell calls, NO process spawning.
//   Results cached via NSCache — zero repeated I/O cost after first check.

import FileModelKit
import Foundation

// MARK: - EncryptedArchiveCheck
enum EncryptedArchiveCheck {
    // MARK: - Cache (NSCache is internally thread-safe)
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSNumber>()
    // MARK: - Public API
    /// Returns true if archive is encrypted.
    /// Pure file-header reads only — no shell calls, safe for main thread.
    static func isEncrypted(url: URL) -> Bool {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached.boolValue
        }
        let result = detect(url: url)
        cache.setObject(NSNumber(value: result), forKey: key)
        return result
    }
    /// Invalidate cache for a specific file
    static func invalidate(url: URL) {
        cache.removeObject(forKey: url.path as NSString)
    }
    // MARK: - Detection Router
    private static func detect(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        switch ext {
            case "zip":
                return checkZipHeader(url: url)
            case "7z":
                return check7zHeader(url: url)
            case "rar":
                return checkRarHeader(url: url)
            default:
                return false
        }
    }
    // MARK: - ZIP Header Check
    /// Reads PK\x03\x04 + General Purpose Bit Flag (bit 0). Cost: 8 bytes.
    private static func checkZipHeader(url: URL) -> Bool {
        guard let data = readBytes(url: url, count: 8), data.count >= 8 else { return false }
        guard data[0] == 0x50, data[1] == 0x4B, data[2] == 0x03, data[3] == 0x04 else { return false }
        let flags = UInt16(data[6]) | (UInt16(data[7]) << 8)
        return (flags & 0x0001) != 0
    }
    // MARK: - 7z Header Check
    /// 7z signature: 37 7A BC AF 27 1C (6 bytes), then 2 bytes version, then
    /// 4 bytes StartHeaderCRC, 8 bytes NextHeaderOffset, 8 bytes NextHeaderSize,
    /// 4 bytes NextHeaderCRC — total 32 bytes.
    /// If header is encrypted, 7z stores EncryptedHeader marker: the encoded header
    /// starts at NextHeaderOffset and if that's 0 or very small with non-zero size,
    /// it's a strong indicator. But the simplest reliable check:
    /// try to read the property IDs — encrypted 7z has kEncodedHeader (0x17) at start
    /// of the header block, while normal archives have kHeader (0x01).
    /// For icon purposes: read 32+16 bytes, seek to NextHeaderOffset, read first byte.
    private static func check7zHeader(url: URL) -> Bool {
        guard let data = readBytes(url: url, count: 32), data.count >= 32 else { return false }
        // Verify 7z signature
        guard data[0] == 0x37, data[1] == 0x7A, data[2] == 0xBC, data[3] == 0xAF,
            data[4] == 0x27, data[5] == 0x1C
        else { return false }
        // Read NextHeaderOffset (little-endian UInt64 at offset 12)
        let nextHeaderOffset = readUInt64LE(data, offset: 12)
        // Read NextHeaderSize (little-endian UInt64 at offset 20)
        let nextHeaderSize = readUInt64LE(data, offset: 20)
        // Sanity: if NextHeaderSize is 0 the archive is empty
        guard nextHeaderSize > 0 else { return false }
        // The encoded header starts at file offset 32 + NextHeaderOffset
        let headerFileOffset = 32 + nextHeaderOffset
        // Read first byte of the actual header block
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: headerFileOffset)
            guard let headerByte = try handle.read(upToCount: 1), headerByte.count == 1 else { return false }
            // 0x17 = kEncodedHeader → headers are encoded (encrypted)
            // 0x01 = kHeader → normal unencrypted header
            return headerByte[0] == 0x17
        } catch {
            return false
        }
    }
    // MARK: - RAR Header Check
    /// RAR5 signature: 52 61 72 21 1A 07 01 00 (8 bytes)
    /// RAR4 signature: 52 61 72 21 1A 07 00
    /// RAR5: encryption info is in a separate header block — check for
    /// encryption record (header type 4 = encryption header) following the main header.
    /// RAR4: archive flags at offset 10, bit 7 (0x0080) = encrypted headers.
    private static func checkRarHeader(url: URL) -> Bool {
        guard let data = readBytes(url: url, count: 20), data.count >= 12 else { return false }
        // Check RAR signature
        guard data[0] == 0x52, data[1] == 0x61, data[2] == 0x72, data[3] == 0x21,
            data[4] == 0x1A, data[5] == 0x07
        else { return false }
        if data[6] == 0x00 {
            // RAR4: flags at offset 8-9 (after 7-byte signature)
            // Archive header flags at offset 10 (after 3-byte header type)
            // Simpler: check if there's a FILE_HEAD with PASSWORD flag
            // In the main archive header (type 0x73), flags at offset 9-10
            if data.count >= 13 {
                // Main archive header: CRC(2) TYPE(1) FLAGS(2) SIZE(2)
                // TYPE=0x73 at offset 9, FLAGS at offset 10-11
                let flags = UInt16(data[10]) | (UInt16(data[11]) << 8)
                // Bit 7 = headers are encrypted
                if (flags & 0x0080) != 0 { return true }
            }
        } else if data[6] == 0x01 && data[7] == 0x00 {
            // RAR5: after 8-byte signature comes the archive header
            // Header CRC32(4), HeaderSize(vint), HeaderType(vint)
            // HeaderType 4 = Encryption header — if present before file headers,
            // the archive is encrypted.
            // Simple heuristic: scan next ~50 bytes for header type 4
            guard let extended = readBytes(url: url, count: 64), extended.count >= 20 else { return false }
            // Skip signature (8 bytes), check for encryption header type (0x04)
            for i in 8..<(extended.count - 1) {
                // vint encoding: if high bit clear, it's the value directly
                if extended[i] == 0x04 && i > 8 {
                    return true
                }
            }
        }
        return false
    }
    // MARK: - Helpers
    private static func readBytes(url: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: count)
    }
    private static func readUInt64LE(_ data: Data, offset: Int) -> UInt64 {
        guard offset + 8 <= data.count else { return 0 }
        var result: UInt64 = 0
        for i in 0..<8 {
            result |= UInt64(data[offset + i]) << (i * 8)
        }
        return result
    }
}
