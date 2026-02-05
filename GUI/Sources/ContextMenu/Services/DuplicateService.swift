// DuplicateService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for file duplication (Finder-style naming)

import Foundation

// MARK: - Duplicate Service
/// Handles file duplication with Finder-style naming ("File copy.txt", "File copy 2.txt")
@MainActor
final class DuplicateService {
    
    static let shared = DuplicateService()
    private let fileManager = FileManager.default
    
    private init() {
        log.debug("\(#function) DuplicateService initialized")
    }
    
    // MARK: - Duplicate File
    
    /// Duplicates a file with Finder-style naming
    /// Returns URL of the created duplicate
    @discardableResult
    func duplicate(file: URL) async throws -> URL {
        log.debug("\(#function) file='\(file.lastPathComponent)' path='\(file.path)'")
        
        let parentDir = file.deletingLastPathComponent()
        let duplicateName = generateDuplicateName(for: file)
        let duplicateURL = parentDir.appendingPathComponent(duplicateName)
        
        log.info("\(#function) duplicating '\(file.lastPathComponent)' → '\(duplicateName)'")
        
        try fileManager.copyItem(at: file, to: duplicateURL)
        
        log.info("\(#function) SUCCESS created: '\(duplicateURL.lastPathComponent)'")
        return duplicateURL
    }
    
    /// Duplicates multiple files
    func duplicate(files: [URL]) async throws -> [URL] {
        log.debug("\(#function) files.count=\(files.count)")
        
        var duplicates: [URL] = []
        
        for file in files {
            let duplicate = try await duplicate(file: file)
            duplicates.append(duplicate)
        }
        
        log.info("\(#function) duplicated \(duplicates.count) file(s)")
        return duplicates
    }
    
    // MARK: - Private Helpers
    
    /// Generates duplicate name following Finder conventions:
    /// "File.txt" → "File copy.txt"
    /// "File copy.txt" → "File copy 2.txt"
    private func generateDuplicateName(for file: URL) -> String {
        let parentDir = file.deletingLastPathComponent()
        let fileName = file.deletingPathExtension().lastPathComponent
        let fileExtension = file.pathExtension
        let hasExtension = !fileExtension.isEmpty
        
        // Check if already a copy
        let copyPattern = #"^(.+) copy( \d+)?$"#
        let regex = try? NSRegularExpression(pattern: copyPattern)
        let range = NSRange(fileName.startIndex..., in: fileName)
        
        let baseName: String
        var counter = 1
        
        if let match = regex?.firstMatch(in: fileName, range: range),
           let baseRange = Range(match.range(at: 1), in: fileName) {
            // Already a copy, increment counter
            baseName = String(fileName[baseRange])
            if let counterRange = Range(match.range(at: 2), in: fileName) {
                let counterStr = String(fileName[counterRange]).trimmingCharacters(in: .whitespaces)
                counter = (Int(counterStr) ?? 1) + 1
            } else {
                counter = 2
            }
            log.debug("\(#function) detected existing copy, baseName='\(baseName)' nextCounter=\(counter)")
        } else {
            baseName = fileName
        }
        
        // Generate unique name
        while true {
            let candidateName: String
            if counter == 1 {
                candidateName = hasExtension ? "\(baseName) copy.\(fileExtension)" : "\(baseName) copy"
            } else {
                candidateName = hasExtension ? "\(baseName) copy \(counter).\(fileExtension)" : "\(baseName) copy \(counter)"
            }
            
            let candidateURL = parentDir.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                log.debug("\(#function) generated name='\(candidateName)'")
                return candidateName
            }
            counter += 1
        }
    }
}
