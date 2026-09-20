// SearchTextMatcher.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Case- and whitespace-insensitive substring matching with source-range mapping.

import Foundation

// MARK: - Search Text Matcher
enum SearchTextMatcher {
    // MARK: - Reusable Search Index
    struct Index: Sendable {
        let id = UUID()
        fileprivate let text: String
        fileprivate let sourceRanges: [NSRange]

        init(_ source: String) {
            let indexed = indexedCanonical(source)
            text = indexed.text
            sourceRanges = indexed.sourceRanges
        }

        func ranges(for query: String) -> [NSRange] {
            let needle = canonical(query)
            guard !needle.isEmpty, !text.isEmpty else { return [] }
            let haystack = text as NSString
            var results: [NSRange] = []
            var location = 0
            while location < haystack.length {
                let searchRange = NSRange(location: location, length: haystack.length - location)
                let normalizedRange = haystack.range(of: needle, range: searchRange)
                guard normalizedRange.location != NSNotFound else { break }
                let first = sourceRanges[normalizedRange.location]
                let last = sourceRanges[NSMaxRange(normalizedRange) - 1]
                results.append(NSRange(location: first.location, length: NSMaxRange(last) - first.location))
                location = NSMaxRange(normalizedRange)
            }
            return results
        }
    }

    // MARK: - Settings Match
    static func matches(_ source: String, query: String) -> Bool {
        let compactQuery = canonical(query)
        guard !compactQuery.isEmpty else { return true }
        let compactSource = canonical(source)
        if compactSource.contains(compactQuery) { return true }
        let fragments = query.split(whereSeparator: { $0.isWhitespace }).map { canonical(String($0)) }
        return !fragments.isEmpty && fragments.allSatisfy(compactSource.contains)
    }

    // MARK: - Source Range
    static func range(
        in source: String,
        query: String,
        after originalLocation: Int,
        backwards: Bool
    ) -> NSRange? {
        let needle = canonical(query)
        guard !needle.isEmpty else { return nil }
        let indexed = Index(source)
        guard !indexed.text.isEmpty else { return nil }
        let haystack = indexed.text as NSString
        let searchRange: NSRange
        if backwards {
            let end = indexed.sourceRanges.lastIndex { NSMaxRange($0) <= originalLocation }.map { $0 + 1 } ?? 0
            searchRange = NSRange(location: 0, length: end)
        } else {
            let start = indexed.sourceRanges.firstIndex { $0.location >= originalLocation } ?? indexed.sourceRanges.count
            searchRange = NSRange(location: start, length: indexed.sourceRanges.count - start)
        }
        let options: NSString.CompareOptions = backwards ? [.backwards] : []
        let normalizedRange = haystack.range(of: needle, options: options, range: searchRange)
        guard normalizedRange.location != NSNotFound else { return nil }
        let first = indexed.sourceRanges[normalizedRange.location]
        let last = indexed.sourceRanges[NSMaxRange(normalizedRange) - 1]
        return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
    }

    // MARK: - Canonical Form
    private static func canonical(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .map(String.init)
            .joined()
    }

    // MARK: - Indexed Canonical Form
    private static func indexedCanonical(_ source: String) -> (text: String, sourceRanges: [NSRange]) {
        var text = ""
        var sourceRanges: [NSRange] = []
        for range in source.indices.map({ $0..<source.index(after: $0) }) {
            let originalRange = NSRange(range, in: source)
            let folded = canonical(String(source[range]))
            text.append(contentsOf: folded)
            sourceRanges.append(contentsOf: repeatElement(originalRange, count: folded.utf16.count))
        }
        return (text, sourceRanges)
    }
}
