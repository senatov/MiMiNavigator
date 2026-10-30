// JunkAIReviewer.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation
import FoundationModels

// MARK: - On-Device Cleanup Review
enum JunkAIReviewer {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }
    static var statusText: String {
        switch SystemLanguageModel.default.availability {
        case .available: "Apple Intelligence ready for app leftover review"
        case .unavailable(.modelNotReady): "Apple Intelligence model is not ready on this Mac"
        case .unavailable(.deviceNotEligible): "Apple Intelligence is not supported on this Mac"
        case .unavailable: "Apple Intelligence is unavailable on this Mac"
        }
    }

    // MARK: - Review Possible Application Leftover
    static func review(_ url: URL, category: String) async -> Bool? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
            Classify a possible macOS application leftover from its path and category only. \
            You cannot inspect the file, installed applications, or the user's intent. \
            Reply with exactly KEEP or REVIEW. Choose KEEP whenever the path could plausibly \
            contain user documents, shared data, credentials, or an active service. \
            REVIEW only for a clearly app-specific cache, log, preference, or saved state. \
            Do not claim that deletion is safe.
            """)
        do {
            let response = try await session.respond(to: "Category: \(category)\nPath: \(url.path)")
            let verdict = response.content.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if verdict == "REVIEW" { return true }
            if verdict == "KEEP" { return false }
            return nil
        } catch {
            log.warning("[Cleanup] On-device review unavailable for \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
}
