// RemoteTransferProgress.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Observable state model for remote upload/download operations.
//   Drives RemoteTransferConsole. Thread-safe: all mutations on MainActor.
//   Console log lines are capped at maxLogLines to avoid memory bloat.

import Foundation

// MARK: - RemoteTransferDirection
enum RemoteTransferDirection {
    case upload   // local → remote
    case download // remote → local

    var title: String {
        switch self {
        case .upload:   return "Upload"
        case .download: return "Download"
        }
    }
    var icon: String {
        switch self {
        case .upload:   return "arrow.up.to.line.circle.fill"
        case .download: return "arrow.down.to.line.circle.fill"
        }
    }
}

// MARK: - RemoteTransferItem
struct RemoteTransferItem: Identifiable, Sendable {
    let id = UUID()
    let remotePath: String
    let localURL:   URL
    let size:       Int64          // 0 if unknown
    var transferred: Int64 = 0
    var done:        Bool  = false
    var failed:      Bool  = false
    var errorMsg:    String?

    var name: String { (remotePath as NSString).lastPathComponent }
    var fraction: Double {
        guard size > 0 else { return done ? 1 : 0 }
        return min(1, Double(transferred) / Double(size))
    }
}

// MARK: - RemoteTransferProgress
@MainActor
@Observable
final class RemoteTransferProgress {

    // MARK: - Static config
    private static let maxLogLines = 400

    // MARK: - Identity
    let direction:   RemoteTransferDirection
    let serverLabel: String     // e.g. "SFTP demo@test.rebex.net"
    let startedAt:   Date = Date()

    // MARK: - Items
    var items: [RemoteTransferItem]

    // MARK: - Live counters
    var doneCount:      Int   = 0
    var failedCount:    Int   = 0
    var totalBytes:     Int64 = 0
    var transferredBytes: Int64 = 0

    // MARK: - State
    var isRunning:    Bool = true
    var isCancelled:  Bool = false
    var isCompleted:  Bool = false
    var currentName:  String = ""

    // MARK: - Console log
    var logLines: [String] = []

    // MARK: - Computed

    var totalFiles: Int { items.count }

    var fraction: Double {
        guard totalBytes > 0 else {
            guard totalFiles > 0 else { return 0 }
            return Double(doneCount) / Double(totalFiles)
        }
        return min(1, Double(transferredBytes) / Double(totalBytes))
    }

    var elapsed: TimeInterval { Date().timeIntervalSince(startedAt) }

    var bytesPerSecond: Double {
        guard elapsed > 0 else { return 0 }
        return Double(transferredBytes) / elapsed
    }

    var etaText: String {
        guard isRunning, bytesPerSecond > 0,
              totalBytes > transferredBytes else { return "" }
        let secs = Double(totalBytes - transferredBytes) / bytesPerSecond
        if secs < 60  { return String(format: "%.0fs left", secs) }
        if secs < 3600 { return String(format: "%.0fm left", secs / 60) }
        return String(format: "%.1fh left", secs / 3600)
    }

    var speedText: String {
        guard isRunning, bytesPerSecond > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond),
                                         countStyle: .file) + "/s"
    }

    var statusLine: String {
        if isCancelled  { return "Cancelled — \(doneCount)/\(totalFiles) files" }
        if isCompleted {
            let ok = doneCount - failedCount
            if failedCount == 0 { return "Done — \(ok) file(s) \(direction == .upload ? "uploaded" : "downloaded")" }
            return "Done — \(ok) OK, \(failedCount) failed"
        }
        return "\(direction.title) \(doneCount + 1)/\(totalFiles)"
    }

    // MARK: - Init
    init(direction: RemoteTransferDirection,
         serverLabel: String,
         items: [RemoteTransferItem])
    {
        self.direction    = direction
        self.serverLabel  = serverLabel
        self.items        = items
        self.totalBytes   = items.reduce(0) { $0 + $1.size }
    }

    // MARK: - Mutations (called by transfer engine)

    func startItem(id: UUID, name: String) {
        currentName = name
        appendLog("→ \(name)")
    }

    func updateItem(id: UUID, transferred: Int64) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let delta = transferred - items[idx].transferred
        items[idx].transferred  = transferred
        transferredBytes       += delta
    }

    func completeItem(id: UUID, success: Bool, error: String? = nil) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].done   = true
        items[idx].failed = !success
        items[idx].errorMsg = error
        doneCount += 1
        if !success {
            failedCount += 1
            appendLog("✗ \(items[idx].name): \(error ?? "failed")")
        } else {
            let sz = items[idx].size > 0
                ? " (\(ByteCountFormatter.string(fromByteCount: items[idx].size, countStyle: .file)))"
                : ""
            appendLog("✓ \(items[idx].name)\(sz)")
        }
    }

    func cancel() {
        isCancelled = true
        isRunning   = false
        appendLog("— Transfer cancelled by user")
        log.info("[RemoteTransfer] cancelled \(doneCount)/\(totalFiles)")
    }

    func complete() {
        isCompleted = true
        isRunning   = false
        let elapsed = String(format: "%.1f", self.elapsed)
        appendLog("— Done in \(elapsed)s: \(doneCount - failedCount) OK, \(failedCount) failed")
        log.info("[RemoteTransfer] completed \(doneCount) files, \(failedCount) errors, \(elapsed)s")
    }

    func appendLog(_ line: String) {
        let ts  = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let full = "\(ts)  \(line)"
        logLines.append(full)
        if logLines.count > Self.maxLogLines {
            logLines.removeFirst(logLines.count - Self.maxLogLines)
        }
    }
}
