// MenuBarDiagnostics.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reads bounded current-session error summaries for the menu bar popover.

import Foundation

// MARK: - Menu Bar System Issue
struct MenuBarSystemIssue: Identifiable, Hashable {
    let id: String
    let message: String
}

// MARK: - Menu Bar Diagnostics
enum MenuBarDiagnostics {
    private static let logURL = URL(fileURLWithPath: "/private/tmp/MiMiNavigator.log")
    private static let maximumReadBytes: UInt64 = 256 * 1_024

    // MARK: - Current Log Offset
    static func currentLogOffset() -> UInt64 {
        let values = try? logURL.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values?.fileSize ?? 0)
    }

    // MARK: - Current Session Issues
    static func issues(since initialOffset: UInt64) -> [MenuBarSystemIssue] {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else { return [] }
        defer { try? handle.close() }
        let endOffset = (try? handle.seekToEnd()) ?? 0
        guard endOffset > initialOffset else { return [] }
        let startOffset = max(initialOffset, endOffset > maximumReadBytes ? endOffset - maximumReadBytes : 0)
        try? handle.seek(toOffset: startOffset)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return [] }
        var seen = Set<String>()
        let messages = text.split(separator: "\n").reversed().compactMap { line -> String? in
            let value = String(line)
            guard value.contains(" ERROR "), let range = value.range(of: " - ", options: .backwards) else { return nil }
            let message = String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !message.isEmpty, seen.insert(message).inserted else { return nil }
            return message
        }
        return messages.prefix(3).map { MenuBarSystemIssue(id: $0, message: $0) }
    }
}
