// JunkAIReviewer.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation
import FoundationModels

// MARK: - On-Device Cleanup Review
enum JunkAIReviewer {

    // MARK: - Availability State

    /// Flattened view of SystemLanguageModel.Availability, easier to log and branch on.
    enum AvailabilityState: Equatable, Sendable {
        case ready
        case disabledInSettings
        case modelNotReady
        case deviceNotEligible
        case unknown(String)

        /// True when the state can resolve itself without user action (model still downloading/preparing).
        var isTransient: Bool { self == .modelNotReady }
    }

    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static var state: AvailabilityState {
        switch SystemLanguageModel.default.availability {
        case .available: .ready
        case .unavailable(.appleIntelligenceNotEnabled): .disabledInSettings
        case .unavailable(.modelNotReady): .modelNotReady
        case .unavailable(.deviceNotEligible): .deviceNotEligible
        case .unavailable(let other): .unknown(String(describing: other))
        }
    }

    static var statusText: String {
        switch state {
        case .ready: "Apple Intelligence ready for app leftover review"
        case .disabledInSettings: "Apple Intelligence is turned off in System Settings"
        case .modelNotReady: "Apple Intelligence model is not ready on this Mac (downloading or preparing)"
        case .deviceNotEligible: "Apple Intelligence is not supported on this Mac"
        case .unknown(let reason): "Apple Intelligence is unavailable: \(reason)"
        }
    }

    // MARK: - Verdict

    /// Constrained output: the model can only return one of these two cases.
    @Generable
    enum Verdict {
        case keep
        case review
    }

    private static let instructions = """
        Classify a possible macOS application leftover from its path and category only. \
        You cannot inspect the file, installed applications, or the user's intent. \
        Choose keep whenever the path could plausibly contain user documents, shared data, \
        credentials, or an active service. \
        Choose review only for a clearly app-specific cache, log, preference, or saved state. \
        Do not claim that deletion is safe.
        """

    // MARK: - Diagnostics

    /// Multi-line snapshot of everything that can influence model availability.
    static func diagnosticReport() -> String {
        let model = SystemLanguageModel.default
        let locale = Locale.current
        let process = ProcessInfo.processInfo
        let currentState = state

        var lines: [String] = []
        lines.append("state: \(currentState)")
        lines.append("isAvailable: \(model.isAvailable)")
        lines.append("macOS: \(process.operatingSystemVersionString)")
        lines.append("locale: \(locale.identifier), region: \(locale.region?.identifier ?? "n/a")")
        lines.append("preferredLanguages: \(Locale.preferredLanguages.joined(separator: ", "))")
        lines.append("locale supported by model: \(model.supportsLocale(locale))")
        lines.append("model supportedLanguages: \(model.supportedLanguages)")
        if let freeGB = freeDiskGB() {
            let enough = freeGB >= 7 ? "ok" : "LOW, Apple Intelligence needs about 7 GB"
            lines.append("free disk: \(String(format: "%.1f", freeGB)) GB (\(enough))")
        } else {
            lines.append("free disk: n/a")
        }
        lines.append("low power mode: \(process.isLowPowerModeEnabled)")
        lines.append("thermal state: \(thermalDescription(process.thermalState))")
        for hint in hints(for: currentState) {
            lines.append("hint: \(hint)")
        }
        return lines.joined(separator: "\n")
    }

    static func logDiagnostics() {
        log.info("[Cleanup] Apple Intelligence diagnostics:\n\(diagnosticReport())")
    }

    private static func hints(for state: AvailabilityState) -> [String] {
        switch state {
        case .ready:
            return []
        case .disabledInSettings:
            return ["Enable Apple Intelligence in System Settings > Apple Intelligence & Siri"]
        case .modelNotReady:
            return [
                "Keep the Mac on Wi-Fi and power until the model download finishes",
                "Check that system language and Siri language are the same supported language",
                "Check Region in System Settings > General > Language & Region",
                "Keep at least 7 GB free; disable Low Power Mode while downloading",
                "If nothing changes after 20-30 minutes, restart the Mac",
            ]
        case .deviceNotEligible:
            return [
                "Requires Apple Silicon; this state does not resolve itself",
                "Check system language, Siri language and Region",
            ]
        case .unknown:
            return ["Unknown reason: check the raw state above and the system logs"]
        }
    }

    private static func freeDiskGB() -> Double? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard
            let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
            let bytes = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return Double(bytes) / 1_073_741_824
    }

    private static func thermalDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    // MARK: - Waiting For The Model

    /// Polls with exponential backoff while the model is in the transient `modelNotReady` state.
    /// Returns early (false) for states that cannot resolve themselves, e.g. disabled in Settings.
    @discardableResult
    static func waitUntilAvailable(timeout: Duration = .seconds(90)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var delay: Duration = .seconds(2)

        while !isAvailable {
            guard state.isTransient else { return false }
            guard clock.now < deadline else { return false }
            do {
                try await Task.sleep(for: delay)
            } catch {
                // Task cancelled: report whatever the model state is right now
                return isAvailable
            }
            delay = min(delay * 2, .seconds(15))
        }
        return true
    }

    /// Call once before a batch of reviews: logs diagnostics when unavailable, waits for the
    /// model to become ready, then prewarms it. There is no public API to force a model
    /// download or restart; waiting and re-creating sessions is all an app can do.
    static func prepare(timeout: Duration = .seconds(90)) async -> Bool {
        if !isAvailable {
            log.warning("[Cleanup] Model unavailable (\(state)); waiting up to \(timeout)")
            logDiagnostics()
            guard await waitUntilAvailable(timeout: timeout) else {
                log.warning("[Cleanup] Model still unavailable: \(statusText)")
                return false
            }
            log.info("[Cleanup] Model became ready")
        }
        // Throwaway session just to load model resources ahead of the first request
        LanguageModelSession(instructions: instructions).prewarm()
        return true
    }

    // MARK: - Review Possible Application Leftover

    /// Returns true for REVIEW, false for KEEP, nil when the model is unavailable or failed.
    static func review(_ url: URL, category: String, maxAttempts: Int = 2) async -> Bool? {
        guard isAvailable else {
            log.warning("[Cleanup] Skipping AI review for \(url.path): \(statusText)")
            return nil
        }
        let prompt = "Category: \(category)\nPath: \(url.path)"

        for attempt in 1...max(1, maxAttempts) {
            // Fresh session per attempt: independent verdicts and no accumulated context
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: Verdict.self,
                    options: GenerationOptions(samplingMode: .greedy)
                )
                return response.content == Verdict.review
            } catch is CancellationError {
                return nil
            } catch {
                log.warning(
                    "[Cleanup] Review attempt \(attempt)/\(maxAttempts) failed for \(url.path): \(String(describing: error))"
                )
                guard attempt < maxAttempts else { return nil }
                try? await Task.sleep(for: .seconds(attempt))
                // The model may have dropped out between attempts (e.g. update or re-download)
                guard await waitUntilAvailable(timeout: .seconds(20)) else { return nil }
            }
        }
        return nil
    }
}
