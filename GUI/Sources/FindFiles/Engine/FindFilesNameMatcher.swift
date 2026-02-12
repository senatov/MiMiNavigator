// FindFilesNameMatcher.swift
// MiMiNavigator
//
// Extracted from FindFilesEngine.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: File name glob pattern matching (wildcards: *, ?)

import Foundation

// MARK: - Name Matcher
/// Converts glob patterns (*.txt, report?) to regex and matches file names
enum FindFilesNameMatcher {

    /// Build NSRegularExpression from glob pattern. Returns nil for "*" or empty patterns.
    static func buildRegex(pattern: String, caseSensitive: Bool) -> NSRegularExpression? {
        if pattern.isEmpty || pattern == "*" || pattern == "*.*" { return nil }

        // Support multiple patterns separated by ";"
        let subPatterns = pattern.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if subPatterns.isEmpty { return nil }

        let regexParts = subPatterns.map { singleGlobToRegex($0) }
        let combined = regexParts.joined(separator: "|")
        let fullRegex = "^(\(combined))$"

        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: fullRegex, options: options)
    }

    /// Match file name against pre-built regex
    static func matches(fileName: String, regex: NSRegularExpression?, criteria: FindFilesCriteria) -> Bool {
        if criteria.fileNamePattern.isEmpty || criteria.fileNamePattern == "*" || criteria.fileNamePattern == "*.*" {
            return true
        }
        guard let regex else { return true }
        let range = NSRange(fileName.startIndex..., in: fileName)
        return regex.firstMatch(in: fileName, range: range) != nil
    }

    // MARK: - Private

    /// Convert a single glob pattern to regex string (without anchors)
    private static func singleGlobToRegex(_ pattern: String) -> String {
        var regexStr = ""
        for char in pattern {
            switch char {
            case "*": regexStr += ".*"
            case "?": regexStr += "."
            case ".": regexStr += "\\."
            case "(", ")", "[", "]", "{", "}", "+", "^", "$", "|", "\\": regexStr += "\\\(char)"
            default: regexStr += String(char)
            }
        }
        return regexStr
    }
}
