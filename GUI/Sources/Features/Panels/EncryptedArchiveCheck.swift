// EncryptedArchiveCheck.swift
// MiMiNavigator
//
// Created by Claude on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Encrypted archive detection for icon display.
//   ZIP: reads 8 bytes from Local File Header (bit 0 of General Purpose Flag).
//   7z:  runs `7z l -slt` — checks exit code and "Encrypted = +" marker.
//   RAR: runs `unrar lt` — checks for encryption markers, fallback to 7z.
//   Results cached via NSCache — zero repeated I/O cost after first check.

import FileModelKit
import Foundation

// MARK: - EncryptedArchiveCheck
enum EncryptedArchiveCheck {
    // MARK: - Cache (NSCache is internally thread-safe)
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSNumber>()
    // MARK: - Public API
    /// Returns true if archive is encrypted.
    /// Supports ZIP (instant), 7z, RAR (via shell, cached).
    static func isEncrypted(url: URL) -> Bool {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached.boolValue
        }
        let result = detect(url: url)
        cache.setObject(NSNumber(value: result), forKey: key)
        return result
    }
    /// Invalidate cache for a specific file (e.g. after modification)
    static func invalidate(url: URL) {
        cache.removeObject(forKey: url.path as NSString)
    }
    // MARK: - Detection Router
    private static func detect(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "zip":
            return checkZipHeader(url: url) || checkVia7z(url: url)
        case "7z":
            return checkVia7z(url: url)
        case "rar":
            return checkViaUnrar(url: url) ?? checkVia7z(url: url)
        default:
            // Other archive formats handled by 7z (cab, arj, etc.)
            if ArchiveExtensions.isArchive(ext) {
                return checkVia7z(url: url)
            }
            return false
        }
    }
    // MARK: - ZIP Header Check
    /// Reads PK signature + General Purpose Bit Flag. Bit 0 = encrypted.
    /// Cost: 8 bytes, instant.
    private static func checkZipHeader(url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 8), data.count >= 8 else { return false }
        guard data[0] == 0x50, data[1] == 0x4B, data[2] == 0x03, data[3] == 0x04 else { return false }
        let flags = UInt16(data[6]) | (UInt16(data[7]) << 8)
        return (flags & 0x0001) != 0
    }
    // MARK: - 7z Shell Check
    /// Runs `7z l -slt <archive>`. Encrypted header → exit != 0.
    /// Encrypted content → output contains "Encrypted = +".
    private static func checkVia7z(url: URL) -> Bool {
        guard let bin = findExecutable("7z") else { return false }
        let (exit, stdout, stderr) = shell(bin, "l", "-slt", url.path)
        // Non-zero exit with password/encrypted message → header-encrypted
        if exit != 0 {
            let combined = (stdout + stderr).lowercased()
            if combined.contains("password") || combined.contains("encrypted") || combined.contains("headers error") {
                return true
            }
            return false
        }
        // Content-encrypted: individual entries marked
        return stdout.contains("Encrypted = +")
    }
    // MARK: - RAR Shell Check
    /// Runs `unrar lt <archive>`. Returns nil if unrar not found.
    private static func checkViaUnrar(url: URL) -> Bool? {
        guard let bin = findExecutable("unrar") else { return nil }
        let (exit, stdout, stderr) = shell(bin, "lt", url.path)
        let combined = (stdout + stderr).lowercased()
        if exit != 0 && (combined.contains("encrypted") || combined.contains("password")) {
            return true
        }
        if stdout.lowercased().contains("encrypted") {
            return true
        }
        if exit == 0 { return false }
        return nil // inconclusive, let caller fallback to 7z
    }
    // MARK: - Shell Helper
    private static func shell(_ args: String...) -> (Int32, String, String) {
        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: args[0])
        proc.arguments = Array(args.dropFirst())
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        proc.environment = ProcessInfo.processInfo.environment
        do { try proc.run() } catch { return (-1, "", error.localizedDescription) }
        proc.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return (
            proc.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }
    // MARK: - Find Executable
    private static func findExecutable(_ name: String) -> String? {
        ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
