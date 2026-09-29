// DiagnosticReportBuilder.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Builds short, privacy-filtered Blogger comments.

import Foundation

// MARK: - Diagnostic Report Builder
enum DiagnosticReportBuilder {
    static let maximumCommentCharacters = 900

    // MARK: - Make Report
    static func make(title: String, message: String) -> String {
        let body = sanitize("MiMiNavigator \(appVersionString())\nError: \(title)\nWhen: \(message)")
        return String(body.prefix(maximumCommentCharacters))
    }

    // MARK: - Sanitization
    static func sanitize(_ source: String) -> String {
        var result = source
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if !home.isEmpty { result = result.replacingOccurrences(of: home, with: "[HOME]") }
        let user = NSUserName()
        if !user.isEmpty { result = result.replacingOccurrences(of: user, with: "[USER]") }
        result = replacing(#"(?i)\b(?:sftp|ftp|smb|afp|https?)://[^\s/'\"]+"#, in: result, with: "[REMOTE]")
        result = replacing(#"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])"#, in: result, with: "[IP]")
        result = replacing(#"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, in: result, with: "[EMAIL]")
        result = replacing(#"(?i)(token|password|secret|authorization|cookie|api[_-]?key)\s*[:=]\s*[^\s,;]+"#, in: result, with: "$1=[REDACTED]")
        return result
    }

    private static func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    // MARK: - Version
    private static func appVersionString() -> String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build { return "\(short) (\(build))" }
        if let short { return short }
        if let build { return "build \(build)" }
        return "unknown"
    }
}
