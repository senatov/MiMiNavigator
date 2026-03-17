// ConnectToServerView+Helpers.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Static helpers extracted from ConnectToServerView:
//   - portFormatter    — locale-safe integer formatter for Port field
//   - sanitizeHost     — strip invalid hostname chars
//   - iconForProtocol  — SF Symbol name per protocol
//   - exportToExternalSFTP — persist server list to ~/.mimi/
//   - describeError    — human-readable NSError description

import AppKit
import SwiftUI

extension ConnectToServerView {

    // MARK: - portFormatter
    /// Plain integer, no grouping separator — avoids "5.466" on European locales.
    static let portFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle           = .none
        f.usesGroupingSeparator = false
        f.allowsFloats          = false
        f.minimum               = 1
        f.maximum               = 65535
        return f
    }()

    // MARK: - sanitizeHost
    /// Strips whitespace and characters illegal in hostnames/IPs.
    static func sanitizeHost(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: ".-_:"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
    }

    // MARK: - iconForProtocol
    static func iconForProtocol(_ proto: RemoteProtocol) -> String {
        switch proto {
        case .sftp: return "lightbulb.min"
        case .ftp:  return "globe"
        case .smb:  return "externaldrive.connected.to.line.below"
        case .afp:  return "desktopcomputer"
        }
    }

    // MARK: - exportToExternalSFTP
    /// Writes all saved servers to ~/.mimi/external_sftp.json.
    /// Returns the file path on success.
    @discardableResult
    static func exportToExternalSFTP(store: RemoteServerStore) throws -> String {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("external_sftp.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting    = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store.servers)
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    // MARK: - describeError
    /// User-friendly NSError description with diagnostic hints.
    static func describeError(_ error: Error) -> String {
        let nsErr = error as NSError
        var parts: [String] = [nsErr.localizedDescription]
        if let underlying = nsErr.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("Cause: \(underlying.localizedDescription)")
        }
        switch nsErr.domain {
        case NSCocoaErrorDomain:
            switch nsErr.code {
            case 4:   parts.append("Hint: file/directory not found.")
            case 513: parts.append("Hint: permission denied.")
            case 640: parts.append("Hint: encoding error — data may be corrupted.")
            default:  break
            }
        case NSPOSIXErrorDomain:
            switch nsErr.code {
            case 2:  parts.append("Hint: ENOENT — path does not exist.")
            case 13: parts.append("Hint: EACCES — permission denied.")
            case 28: parts.append("Hint: ENOSPC — disk full.")
            default: break
            }
        default: break
        }
        if let recovery = nsErr.localizedRecoverySuggestion {
            parts.append(recovery)
        }
        return parts.joined(separator: "\n")
    }
}
