// UniqueNameGen.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single unique-name generator — replaces 4 duplicate implementations

import Foundation

// MARK: - Unique Name Generator
/// Generates unique file names when target already exists.
/// Format: "name (2).ext", "name (3).ext", etc.
enum UniqueNameGen {

    /// Resolve a unique target URL: if `destination/name` exists, appends counter.
    /// Returns the resolved URL (may be unchanged if no conflict).
    static func resolve(
        name: String,
        in directory: URL,
        fm: FileManager = .default
    ) -> URL {
        let candidate = directory.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else {
            return candidate
        }

        let baseName = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension

        var counter = 2
        var result: URL

        repeat {
            let newName = ext.isEmpty
                ? "\(baseName) (\(counter))"
                : "\(baseName) (\(counter)).\(ext)"
            result = directory.appendingPathComponent(newName)
            counter += 1
        } while fm.fileExists(atPath: result.path) && counter < 10_000

        if counter >= 10_000 {
            log.error("[UniqueNameGen] >10000 conflicts: \(candidate.path)")
        }

        log.debug("[UniqueNameGen] \(name) → \(result.lastPathComponent)")
        return result
    }

    /// Convenience: resolve for a full URL (extracts name and parent dir)
    static func resolve(
        for url: URL,
        fm: FileManager = .default
    ) -> URL {
        resolve(name: url.lastPathComponent, in: url.deletingLastPathComponent(), fm: fm)
    }
}
