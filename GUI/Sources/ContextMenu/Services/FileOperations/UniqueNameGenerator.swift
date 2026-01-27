// UniqueNameGenerator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Generates unique file names for "Keep Both" resolution

import Foundation

// MARK: - Unique Name Generator
/// Generates unique file names when conflicts occur
enum UniqueNameGenerator {
    
    /// Generate unique name by appending counter: "file (1).ext", "file (2).ext", etc.
    static func generate(for url: URL, fileManager: FileManager = .default) -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }
        
        var finalURL = url
        var counter = 1
        
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parentDir = url.deletingLastPathComponent()
        
        while fileManager.fileExists(atPath: finalURL.path) {
            let newName = ext.isEmpty
                ? "\(baseName) (\(counter))"
                : "\(baseName) (\(counter)).\(ext)"
            finalURL = parentDir.appendingPathComponent(newName)
            counter += 1
            
            if counter > 1000 {
                log.error("[UniqueNameGenerator] too many conflicts for: \(url.path)")
                break
            }
        }
        
        log.debug("[UniqueNameGenerator] generated: \(finalURL.lastPathComponent)")
        return finalURL
    }
}
