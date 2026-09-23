// DiagnosticReportBuilder.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Builds bounded diagnostic excerpts and removes personal identifiers and secrets.

import Foundation

// MARK: - Diagnostic Report Builder
enum DiagnosticReportBuilder {
    private static let maximumLogCharacters = 12_000
    private static let contextLineCount = 16

    // MARK: - Make Report
    static func make(title: String, message: String) -> String {
        let excerpt = sanitizedLogExcerpt(matching: [title, message])
        return sanitize("""
        MiMiNavigator error report

        App version: \(appVersionString())
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Date: \(ISO8601DateFormatter().string(from: Date()))

        Error: \(title)
        Details: \(message)

        Relevant log excerpt:
        \(excerpt.isEmpty ? "No matching log fragment was available." : excerpt)
        """)
    }

    // MARK: - Log Excerpt
    private static func sanitizedLogExcerpt(matching needles: [String]) -> String {
        guard let text = readableLogText() else { return "" }
        let lines = text.components(separatedBy: .newlines)
        let normalizedNeedles = needles.flatMap { value in
            value.components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count >= 5 }
                .map { String($0.prefix(80)).lowercased() }
        }
        let matchIndex = lines.indices.reversed().first { index in
            let line = lines[index].lowercased()
            return line.contains("error") || line.contains("failed") || line.contains("❗️")
                || normalizedNeedles.contains(where: line.contains)
        }
        let fallbackIndex = max(0, lines.count - 1)
        let anchor = matchIndex ?? fallbackIndex
        let end = min(lines.count, anchor + contextLineCount + 1)
        let start = max(0, anchor - contextLineCount)
        return sanitize(lines[start..<end].joined(separator: "\n"))
    }

    private static func readableLogText() -> String? {
        let urls = [AppLogger.logFileURL, Optional(AppLogger.tmpLogFileURL)].compactMap { $0 }
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { continue }
            return String(text.suffix(maximumLogCharacters))
        }
        return nil
    }

    // MARK: - Sanitization
    static func sanitize(_ source: String) -> String {
        var result = source
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if !home.isEmpty { result = result.replacingOccurrences(of: home, with: "[HOME]") }
        let user = NSUserName()
        if !user.isEmpty { result = result.replacingOccurrences(of: user, with: "[USER]") }
        result = replacing(#"(?i)\b(?:sftp|ftp|smb|afp|https?)://[^\s/'\"]+"#, in: result, with: "[REMOTE]")
        result = replacing(#"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, in: result, with: "[IP]")
        result = replacing(#"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, in: result, with: "[EMAIL]")
        result = replacing(#"(?i)(token|password|secret|authorization|cookie|api[_-]?key)\s*[:=]\s*[^\s,;]+"#, in: result, with: "$1=[REDACTED]")
        return String(result.prefix(maximumLogCharacters))
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
