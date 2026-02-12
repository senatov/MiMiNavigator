// FindFilesContentSearcher.swift
// MiMiNavigator
//
// Extracted from FindFilesEngine.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Content search inside text files — pattern matching, text file detection

import Foundation

// MARK: - Content Searcher
/// Searches inside file contents for text/regex patterns
enum FindFilesContentSearcher {

    /// Build content search pattern
    static func buildPattern(text: String, caseSensitive: Bool, useRegex: Bool) -> NSRegularExpression? {
        let pattern = useRegex ? text : NSRegularExpression.escapedPattern(for: text)
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    /// Search file content for pattern matches. Returns results with line numbers and context.
    static func searchFileContent(fileURL: URL, pattern: NSRegularExpression) -> [FindFilesResult] {
        var results: [FindFilesResult] = []

        guard isLikelyTextFile(url: fileURL) else { return results }

        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return results }

        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            guard !Task.isCancelled else { break }
            let range = NSRange(line.startIndex..., in: line)
            if pattern.firstMatch(in: line, range: range) != nil {
                let contextLine = String(line.prefix(200))
                let result = FindFilesResult(
                    fileURL: fileURL,
                    matchContext: contextLine,
                    lineNumber: index + 1
                )
                results.append(result)
            }
        }
        return results
    }

    /// Determine if a file is likely text-readable (not binary)
    static func isLikelyTextFile(url: URL) -> Bool {
        let textExtensions: Set<String> = [
            "txt", "md", "swift", "java", "py", "js", "ts", "jsx", "tsx", "html", "htm",
            "css", "scss", "less", "xml", "json", "yaml", "yml", "toml", "ini", "cfg",
            "conf", "properties", "sh", "bash", "zsh", "fish", "bat", "cmd", "ps1",
            "c", "h", "cpp", "hpp", "cc", "cxx", "cs", "go", "rs", "rb", "php",
            "pl", "pm", "r", "scala", "kt", "kts", "gradle", "groovy", "lua",
            "sql", "graphql", "proto", "makefile", "cmake", "dockerfile",
            "gitignore", "gitattributes", "editorconfig", "env", "log", "csv", "tsv",
            "rtf", "tex", "bib", "rst", "adoc", "org", "vim", "el", "lisp", "clj",
            "erl", "ex", "exs", "hs", "ml", "mli", "fs", "fsx", "v", "sv",
            "vhd", "vhdl", "asm", "s", "d", "di", "nim", "zig", "plist", "strings",
            "storyboard", "xib", "xcconfig", "pbxproj", "xcscheme", "entitlements"
        ]
        let ext = url.pathExtension.lowercased()
        if textExtensions.contains(ext) { return true }

        // Files without extension might be text (Makefile, Dockerfile, etc.)
        if ext.isEmpty {
            let name = url.lastPathComponent.lowercased()
            let textNames: Set<String> = [
                "makefile", "dockerfile", "rakefile", "gemfile", "podfile",
                "brewfile", "procfile", "readme", "license", "changelog",
                "authors", "contributors", "todo", "copying"
            ]
            return textNames.contains(name)
        }
        return false
    }
}
