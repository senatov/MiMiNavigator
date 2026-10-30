// JunkScanEngine+Artifacts.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Darwin
import FindFilesKit
import Foundation

// MARK: - Application and Process Artifacts
extension JunkScanEngine {
    // MARK: - Possible Application Leftovers
    static func inspectApplicationLeftovers(into candidates: inout [JunkCandidate]) async throws {
        guard JunkAIReviewer.isAvailable else { return }
        let installed = FindFilesLeftoverSafety.installedApplicationIdentities()
        let running = await MainActor.run {
            Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).map { $0.lowercased() })
        }
        var newReviews = 0
        for directory in FindFilesLeftoverSafety.searchDirectories {
            guard let children = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey, .contentModificationDateKey]) else { continue }
            for child in children {
                try Task.checkCancellation()
                let name = child.lastPathComponent.lowercased()
                guard !name.hasPrefix("."), name.contains("."),
                      !name.hasPrefix("com.apple."), !name.hasPrefix("group.com.apple."),
                      FindFilesLeftoverSafety.isCandidate(child, installedIdentities: installed),
                      !running.contains(where: { name.contains($0) }),
                      let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey, .contentModificationDateKey]),
                      values.isSymbolicLink != true,
                      let modified = values.contentModificationDate,
                      Date().timeIntervalSince(modified) > 180 * 86400 else { continue }
                let recommended: Bool
                if let cached = await JunkScanDatabase.shared.aiReview(for: child, modified: modified) {
                    recommended = cached
                } else {
                    guard newReviews < 40 else { continue }
                    try await waitForIdle()
                    guard let review = await JunkAIReviewer.review(child, category: directory.lastPathComponent) else { continue }
                    recommended = review
                    await JunkScanDatabase.shared.saveAIReview(review, for: child, modified: modified)
                    newReviews += 1
                }
                guard recommended else { continue }
                let reason = "Possible leftover from an uninstalled app; on-device AI recommends review"
                candidates.append(JunkCandidate(url: child, kind: .appLeftover, reason: reason, size: 0, group: nil))
            }
        }
    }

    // MARK: - Stale Process Files
    static func inspectStaleProcessArtifacts(into candidates: inout [JunkCandidate]) async throws {
        let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs", isDirectory: true)
        guard let children = try? FileManager.default.contentsOfDirectory(at: logs, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]) else { return }
        for url in children where url.pathExtension.lowercased() == "pid" {
            try Task.checkCancellation()
            try await waitForIdle()
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate,
                  Date().timeIntervalSince(modified) > 30 * 86400,
                  let pid = processID(in: url), !isProcessRunning(pid) else { continue }
            candidates.append(JunkCandidate(url: url, kind: .processArtifact, reason: "PID \(pid) is absent and this process file is older than 30 days", size: Int64(values.fileSize ?? 0), group: nil))
        }
    }

    // MARK: - Process Identity
    static func processID(in url: URL) -> Int32? {
        guard let data = try? Data(contentsOf: url), data.count < 64,
              let text = String(data: data, encoding: .utf8),
              let number = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), number > 1 else { return nil }
        return number
    }

    static func isProcessRunning(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
