// BasicFileOperations.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Core file operations without UI dialogs

import Foundation

enum BasicFileOperations {
    
    // MARK: - Copy file to destination
    static func copy(_ file: CustomFile, to destinationURL: URL) -> Bool {
        log.info("copy - \(file.nameStr) -> \(destinationURL.path)")
        let sourceURL = file.urlValue
        let targetURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            log.info("Copied to \(targetURL.path)")
            return true
        } catch {
            log.error("Copy failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Move file to destination
    static func move(_ file: CustomFile, to destinationURL: URL) -> Bool {
        log.info("move - \(file.nameStr) -> \(destinationURL.path)")
        let sourceURL = file.urlValue
        let targetURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: targetURL)
            log.info("Moved to \(targetURL.path)")
            return true
        } catch {
            log.error("Move failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Delete file (move to Trash)
    static func delete(_ file: CustomFile) -> Bool {
        log.info("delete - \(file.nameStr)")
        do {
            try FileManager.default.trashItem(at: file.urlValue, resultingItemURL: nil)
            log.info("Moved to Trash: \(file.nameStr)")
            return true
        } catch {
            log.error("Delete failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Create new folder
    static func createFolder(at parentURL: URL, name: String) -> Bool {
        log.info("createFolder - \(name) in \(parentURL.path)")
        let folderURL = parentURL.appendingPathComponent(name)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            log.info("Created folder: \(folderURL.path)")
            return true
        } catch {
            log.error("Create folder failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Remove file at path (helper for overwrite scenarios)
    static func removeItem(atPath path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            log.error("Failed to remove file: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Check if file exists at path
    static func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
