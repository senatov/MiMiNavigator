// OperationJournal.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Transaction journal for file operations — enables rollback on cancel/failure.
//   Records each atomic action (copy, move, delete, mkdir) with enough info to reverse it.

import Foundation

// MARK: - Journal Entry

/// Single atomic action that can be reversed
struct JournalEntry: Sendable {
    let id: UUID
    let timestamp: Date
    let action: JournalAction
    let sourceURL: URL
    let destinationURL: URL?
    let backupURL: URL?      // For delete/overwrite — temp backup location
    var status: EntryStatus
    
    enum EntryStatus: Sendable {
        case pending
        case completed
        case failed(String)
        case rolledBack
    }
}

// MARK: - Journal Action

enum JournalAction: String, Sendable {
    case createDirectory    // Rollback: rmdir
    case copyFile          // Rollback: delete dest
    case moveFile          // Rollback: move back
    case deleteFile        // Rollback: restore from backup
    case deleteDirectory   // Rollback: restore from backup
    case overwriteFile     // Rollback: restore backup
    
    var rollbackVerb: String {
        switch self {
        case .createDirectory: return "Removing"
        case .copyFile:        return "Deleting"
        case .moveFile:        return "Moving back"
        case .deleteFile:      return "Restoring"
        case .deleteDirectory: return "Restoring"
        case .overwriteFile:   return "Restoring"
        }
    }
}

// MARK: - Operation Journal


/// Transaction journal for a single operation — tracks all actions for rollback
@MainActor
final class OperationJournal {
    
    // MARK: - State
    private(set) var entries: [JournalEntry] = []
    private(set) var isRollingBack = false
    private let backupDir: URL
    private let fm = FileManager.default
    
    // MARK: - Init
    init() {
        // Create temp backup directory for this operation
        let sessionID = UUID().uuidString.prefix(8)
        self.backupDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MiMiBackup_\(sessionID)")
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        log.debug("[Journal] Created backup dir: \(backupDir.path)")
    }
    
    deinit {
        // Cleanup backup dir when journal is released
        let dirToRemove = backupDir
        Task {
            try? FileManager.default.removeItem(at: dirToRemove)
        }
    }
    
    // MARK: - Record Actions
    
    /// Record a directory creation
    func recordCreateDirectory(_ url: URL) {
        let entry = JournalEntry(
            id: UUID(),
            timestamp: Date(),
            action: .createDirectory,
            sourceURL: url,
            destinationURL: nil,
            backupURL: nil,
            status: .completed
        )
        entries.append(entry)
        log.verbose("[Journal] +mkdir \(url.lastPathComponent)")
    }
    
    /// Record a file copy
    func recordCopy(from source: URL, to destination: URL) {
        let entry = JournalEntry(
            id: UUID(),
            timestamp: Date(),
            action: .copyFile,
            sourceURL: source,
            destinationURL: destination,
            backupURL: nil,
            status: .completed
        )
        entries.append(entry)
        log.verbose("[Journal] +copy \(source.lastPathComponent) → \(destination.lastPathComponent)")
    }
    
    /// Record a file move
    func recordMove(from source: URL, to destination: URL) {
        let entry = JournalEntry(
            id: UUID(),
            timestamp: Date(),
            action: .moveFile,
            sourceURL: source,
            destinationURL: destination,
            backupURL: nil,
            status: .completed
        )
        entries.append(entry)
        log.verbose("[Journal] +move \(source.lastPathComponent) → \(destination.lastPathComponent)")
    }
    
    /// Record a file/directory deletion — creates backup first!
    func recordDelete(_ url: URL) throws {
        // Create backup before delete
        let backupURL = backupDir.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
        try fm.copyItem(at: url, to: backupURL)
        
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        let entry = JournalEntry(
            id: UUID(),
            timestamp: Date(),
            action: isDir ? .deleteDirectory : .deleteFile,
            sourceURL: url,
            destinationURL: nil,
            backupURL: backupURL,
            status: .completed
        )
        entries.append(entry)
        log.verbose("[Journal] +delete \(url.lastPathComponent) (backup: \(backupURL.lastPathComponent))")
    }
    
    /// Record an overwrite — creates backup of original first!
    func recordOverwrite(original: URL, newSource: URL) throws {
        // Backup original before overwrite
        let backupURL = backupDir.appendingPathComponent(UUID().uuidString + "_" + original.lastPathComponent)
        try fm.copyItem(at: original, to: backupURL)
        
        let entry = JournalEntry(
            id: UUID(),
            timestamp: Date(),
            action: .overwriteFile,
            sourceURL: newSource,
            destinationURL: original,
            backupURL: backupURL,
            status: .completed
        )
        entries.append(entry)
        log.verbose("[Journal] +overwrite \(original.lastPathComponent) (backup exists)")
    }
    
    // MARK: - Rollback
    
    /// Rollback all completed entries in reverse order
    /// Returns number of successfully rolled back entries
    @discardableResult
    func rollback(progress: OperationProgress? = nil) async -> Int {
        guard !isRollingBack else {
            log.warning("[Journal] Already rolling back, ignoring duplicate call")
            return 0
        }
        isRollingBack = true
        
        log.info("[Journal] 🔄 Starting rollback of \(entries.count) entries...")
        var rolledBack = 0
        var errors: [String] = []
        
        // Process in reverse order (LIFO)
        for i in entries.indices.reversed() {
            let entry = entries[i]
            
            // Skip non-completed entries
            guard case .completed = entry.status else { continue }
            
            do {
                try await rollbackEntry(entry)
                entries[i].status = .rolledBack
                rolledBack += 1
                
                // Update progress if provided
                progress?.updateProgress(
                    file: "↩ \(entry.sourceURL.lastPathComponent)",
                    bytes: 0
                )
                
            } catch {
                let msg = "Failed to rollback \(entry.action.rawValue) \(entry.sourceURL.lastPathComponent): \(error.localizedDescription)"
                log.error("[Journal] \(msg)")
                errors.append(msg)
                entries[i].status = .failed(error.localizedDescription)
            }
        }
        
        isRollingBack = false
        
        if errors.isEmpty {
            log.info("[Journal] ✅ Rollback complete: \(rolledBack) entries reversed")
        } else {
            log.warning("[Journal] ⚠️ Rollback partial: \(rolledBack) OK, \(errors.count) failed")
        }
        
        return rolledBack
    }
    
    /// Rollback a single entry
    private func rollbackEntry(_ entry: JournalEntry) async throws {
        switch entry.action {
            
        case .createDirectory:
            // Remove created directory (if empty)
            try fm.removeItem(at: entry.sourceURL)
            log.verbose("[Journal] ↩ rmdir \(entry.sourceURL.lastPathComponent)")
            
        case .copyFile:
            // Delete the copied file
            if let dest = entry.destinationURL {
                try fm.removeItem(at: dest)
                log.verbose("[Journal] ↩ delete copy \(dest.lastPathComponent)")
            }
            
        case .moveFile:
            // Move file back to original location
            if let dest = entry.destinationURL {
                try fm.moveItem(at: dest, to: entry.sourceURL)
                log.verbose("[Journal] ↩ move back \(dest.lastPathComponent) → \(entry.sourceURL.lastPathComponent)")
            }
            
        case .deleteFile, .deleteDirectory:
            // Restore from backup
            if let backup = entry.backupURL, fm.fileExists(atPath: backup.path) {
                try fm.copyItem(at: backup, to: entry.sourceURL)
                log.verbose("[Journal] ↩ restored \(entry.sourceURL.lastPathComponent) from backup")
            }
            
        case .overwriteFile:
            // Restore original from backup
            if let backup = entry.backupURL, let dest = entry.destinationURL {
                try fm.removeItem(at: dest)
                try fm.copyItem(at: backup, to: dest)
                log.verbose("[Journal] ↩ restored original \(dest.lastPathComponent)")
            }
        }
    }
    
    // MARK: - Statistics
    
    var completedCount: Int {
        entries.filter { if case .completed = $0.status { return true }; return false }.count
    }
    
    var failedCount: Int {
        entries.filter { if case .failed = $0.status { return true }; return false }.count
    }
    
    var rolledBackCount: Int {
        entries.filter { if case .rolledBack = $0.status { return true }; return false }.count
    }
}
