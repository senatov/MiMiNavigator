// FileConflictInfo.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model containing information about conflicting files

import Foundation

// MARK: - File Conflict Info
/// Data model holding metadata for source and target files in a conflict
struct FileConflictInfo {
    let sourceURL: URL
    let targetURL: URL
    let sourceName: String
    let targetName: String
    let sourceSize: Int64
    let targetSize: Int64
    let sourceDate: Date?
    let targetDate: Date?
    
    // MARK: - Initialization
    init(source: URL, target: URL) {
        self.sourceURL = source
        self.targetURL = target
        self.sourceName = source.lastPathComponent
        self.targetName = target.lastPathComponent
        
        let fileManager = FileManager.default
        let sourceAttributes = try? fileManager.attributesOfItem(atPath: source.path)
        let targetAttributes = try? fileManager.attributesOfItem(atPath: target.path)
        
        self.sourceSize = (sourceAttributes?[.size] as? NSNumber)?.int64Value ?? 0
        self.targetSize = (targetAttributes?[.size] as? NSNumber)?.int64Value ?? 0
        self.sourceDate = sourceAttributes?[.modificationDate] as? Date
        self.targetDate = targetAttributes?[.modificationDate] as? Date
    }
}
