// ConnectionErrorFormatter.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Readable formatting for remote connection diagnostics.

import Foundation

// MARK: - Connection Error Formatter
enum ConnectionErrorFormatter {
    // MARK: - Summary
    static func summary(result: ConnectionResult, detail: String, server: RemoteServer) -> String {
        let lower = detail.lowercased()
        if lower.contains("no route to host") {
            return "No route to host. Check VPN, network, firewall, and port \(server.port)."
        }
        if lower.contains("connection refused") {
            return "\(server.remoteProtocol.rawValue) service is not accepting connections on port \(server.port)."
        }
        if result == .authFailed {
            return "Authentication failed. Check username, password, or SSH key."
        }
        if result == .timeout {
            return "Connection timed out. Check host reachability and firewall."
        }
        return result.rawValue
    }

    // MARK: - Log Lines
    static func logLines(from detail: String) -> [String] {
        let readable = readableDetail(detail)
        return readable
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Readable Detail
    static func readableDetail(_ detail: String) -> String {
        let compact = detail
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact
            .replacingOccurrences(of: "Connection errors:", with: "Connection errors:\n")
            .replacingOccurrences(of: "), SingleConnectionFailure", with: ")\nSingleConnectionFailure")
            .replacingOccurrences(of: "SingleConnectionFailure(target:", with: "SingleConnectionFailure\n  target:")
            .replacingOccurrences(of: ", error:", with: "\n  error:")
            .replacingOccurrences(of: ", errno:", with: "\n  errno:")
    }
}
