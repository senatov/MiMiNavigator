// RemoteServerURLParser.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Smart URL/string parser for the ConnectToServer dialog.
//   Handles freeform input in Name or Host fields:
//   - Full URLs:           sftp://user:pwd@host:port/path
//   - Scheme only:         ftp://host:port/path
//   - No-scheme userinfo:  user:pwd@host:port/path
//   - Host+port:           host:port  →  proto inferred from standard port
//   - Port 22  → SFTP, 21 → FTP, 445 → SMB, 548 → AFP
//   Populates as many RemoteServer fields as can be inferred.

import Foundation

// MARK: - RemoteServerURLParser
enum RemoteServerURLParser {

    // MARK: - ParseResult
    struct ParseResult {
        var proto:      RemoteProtocol?
        var host:       String?
        var port:       Int?
        var user:       String?
        var password:   String?
        var remotePath: String?
    }

    // MARK: - parse
    /// Returns nil if raw string doesn't look like a connection spec.
    static func parse(_ raw: String) -> ParseResult? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let r = parseSchemeURL(s) { return r }
        if s.contains("@") || (s.contains(":") && !s.hasPrefix("/")) {
            return parseHostString(s)
        }
        return nil
    }

    // MARK: - inferProtocol
    /// Maps well-known port numbers to protocols.
    /// Returns nil for non-standard ports — caller keeps proto unset.
    static func inferProtocol(fromPort port: Int) -> RemoteProtocol? {
        RemoteProtocol.allCases.first { $0.defaultPort == port }
    }

    // MARK: - parseSchemeURL  (sftp:// ftp:// smb:// afp://)
    private static func parseSchemeURL(_ s: String) -> ParseResult? {
        guard let colon = s.firstIndex(of: ":"),
              s[s.index(after: colon)...].hasPrefix("//"),
              let comps = URLComponents(string: s),
              let host = comps.host, !host.isEmpty
        else { return nil }

        var r = ParseResult()
        r.proto = RemoteProtocol.allCases.first { $0.urlScheme == comps.scheme }
        r.host  = host
        r.user  = comps.user?.nilIfEmpty
        r.password = comps.password?.nilIfEmpty
        let path = comps.path
        if path != "/" && !path.isEmpty { r.remotePath = path }

        // Explicit port in URL takes priority; else infer from scheme's default
        if let p = comps.port {
            r.port = p
            // If scheme was unknown but port matches a known protocol, fill proto
            if r.proto == nil { r.proto = inferProtocol(fromPort: p) }
        } else {
            // No explicit port — leave r.port nil (caller uses protocol default)
        }
        return r
    }

    // MARK: - parseHostString  (no scheme prefix)
    // Handles:  user:pwd@host:port/path   user@host:port   host:port/path
    private static func parseHostString(_ s: String) -> ParseResult? {
        var r = ParseResult()
        var remainder = s

        // user[:pwd]@
        if let atIdx = remainder.range(of: "@") {
            let userPart = String(remainder[..<atIdx.lowerBound])
            remainder    = String(remainder[atIdx.upperBound...])
            if let cIdx = userPart.firstIndex(of: ":") {
                r.user     = String(userPart[..<cIdx]).nilIfEmpty
                r.password = String(userPart[userPart.index(after: cIdx)...]).nilIfEmpty
            } else {
                r.user = userPart.nilIfEmpty
            }
        }

        // /path suffix
        if let slashIdx = remainder.firstIndex(of: "/") {
            let path = String(remainder[slashIdx...])
            if path != "/" { r.remotePath = path }
            remainder = String(remainder[..<slashIdx])
        }

        // host:port
        let parts = remainder.split(separator: ":", maxSplits: 1).map(String.init)
        r.host = parts[0].nilIfEmpty
        if parts.count == 2, let p = Int(parts[1]), (1...65535).contains(p) {
            r.port  = p
            r.proto = inferProtocol(fromPort: p)   // ← infer protocol from standard port
        }

        guard r.host != nil else { return nil }
        return r
    }
}

// MARK: - String helper
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
