// MultiRenameEngine.swift
// MiMiNavigator

import Foundation

// MARK: - Multi Rename Error
enum MultiRenameError: LocalizedError {
    case invalidItems
    case moveFailed(String)
    var errorDescription: String? {
        switch self {
        case .invalidItems: return "Resolve the highlighted name conflicts before renaming."
        case .moveFailed(let message): return message
        }
    }
}

// MARK: - Multi Rename Engine
actor MultiRenameEngine {
    static func preview(sources: [MultiRenameSource], rule: MultiRenameRule) -> [MultiRenamePreviewItem] {
        let fileManager = FileManager.default
        let sourcePaths = Set(sources.map { $0.url.standardizedFileURL.path.lowercased() })
        let proposals = sources.enumerated().map { index, source in
            (source, MultiRenamePattern.proposedName(for: source, index: index, rule: rule))
        }
        let counts = Dictionary(grouping: proposals, by: { proposal in
            proposal.0.url.deletingLastPathComponent().appendingPathComponent(proposal.1).standardizedFileURL.path.lowercased()
        }).mapValues(\.count)
        return proposals.map { source, proposedName in
            let destination = source.url.deletingLastPathComponent().appendingPathComponent(proposedName)
            let destinationKey = destination.standardizedFileURL.path.lowercased()
            let issue: String?
            if proposedName.isEmpty {
                issue = "Name cannot be empty"
            } else if proposedName == "." || proposedName == ".." || proposedName.contains("/") || proposedName.contains(":") {
                issue = "Invalid file name"
            } else if counts[destinationKey, default: 0] > 1 {
                issue = "Duplicate target name"
            } else if fileManager.fileExists(atPath: destination.path) && !sourcePaths.contains(destinationKey) {
                issue = "Target already exists"
            } else {
                issue = nil
            }
            return MultiRenamePreviewItem(source: source, proposedName: proposedName, issue: issue)
        }
    }

    func rename(_ items: [MultiRenamePreviewItem]) throws -> MultiRenameResult {
        guard items.allSatisfy({ $0.issue == nil }) else { throw MultiRenameError.invalidItems }
        let changed = items.filter(\.isChanged)
        guard !changed.isEmpty else { return MultiRenameResult(renamedCount: 0) }
        let fileManager = FileManager.default
        var staged: [(item: MultiRenamePreviewItem, temporary: URL)] = []
        var finalized: [(item: MultiRenamePreviewItem, temporary: URL)] = []
        do {
            for item in changed {
                let temporary = uniqueTemporaryURL(beside: item.source.url, fileManager: fileManager)
                try fileManager.moveItem(at: item.source.url, to: temporary)
                staged.append((item, temporary))
            }
            for entry in staged {
                try fileManager.moveItem(at: entry.temporary, to: entry.item.destinationURL)
                finalized.append(entry)
            }
            return MultiRenameResult(renamedCount: changed.count)
        } catch {
            rollback(staged, finalized: finalized, fileManager: fileManager)
            throw MultiRenameError.moveFailed("Rename failed: \(error.localizedDescription)")
        }
    }

    private func uniqueTemporaryURL(beside source: URL, fileManager: FileManager) -> URL {
        let parent = source.deletingLastPathComponent()
        var candidate: URL
        repeat {
            candidate = parent.appendingPathComponent(".mimi-rename-\(UUID().uuidString)")
        } while fileManager.fileExists(atPath: candidate.path)
        return candidate
    }

    private func rollback(_ staged: [(item: MultiRenamePreviewItem, temporary: URL)], finalized: [(item: MultiRenamePreviewItem, temporary: URL)], fileManager: FileManager) {
        for entry in finalized.reversed() where fileManager.fileExists(atPath: entry.item.destinationURL.path) {
            try? fileManager.moveItem(at: entry.item.destinationURL, to: entry.temporary)
        }
        for entry in staged.reversed() where fileManager.fileExists(atPath: entry.temporary.path) {
            try? fileManager.moveItem(at: entry.temporary, to: entry.item.source.url)
        }
    }
}
