// DualDirectoryScanner+Timeout.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 13.06.2026.
// Description: Directory scan timeout race and timeout policy.

import FileModelKit
import Foundation

// MARK: - Scan Timeout Error
struct ScanTimeoutError: LocalizedError {
    let path: String
    let seconds: TimeInterval
    var errorDescription: String? {
        let secondsText = String(format: "%.1f", seconds)
        return "Scan timed out after \(secondsText)s: \(path)"
    }
}

// MARK: - Scan Race Output
private enum ScanRaceOutput: @unchecked Sendable {
    case success([CustomFile])
    case timeout
    case failure(String)
}

// MARK: - Scan Race Result
private final class ScanRaceResult: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<ScanRaceOutput, Never>

    init(_ continuation: CheckedContinuation<ScanRaceOutput, Never>) {
        self.continuation = continuation
    }

    // MARK: - Resume
    func resume(_ result: ScanRaceOutput) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: result)
    }
}

extension DualDirectoryScanner {
    // MARK: - Effective Timeout
    func effectiveTimeout(for url: URL) -> TimeInterval {
        if url.path == "/Volumes" || (url.path.hasPrefix("/Volumes/") && url.path != "/Volumes") {
            return mountedVolumeScanTimeout
        }
        if AppState.isAppManagedNetworkMountPath(url) {
            return mountedVolumeScanTimeout
        }
        return genericScanTimeout
    }

    // MARK: - Mounted Volume Timeout
    func shouldTimeoutSlowVolumeScan(_ url: URL) -> Bool {
        url.path == "/Volumes" || (url.path.hasPrefix("/Volumes/") && url.path != "/Volumes")
    }

    // MARK: - Scan With Timeout
    func scanWithTimeout(
        _ scanTask: Task<[CustomFile], Error>,
        url: URL,
        timeout: TimeInterval? = nil
    ) async throws -> [CustomFile] {
        let effectiveTimeout = timeout ?? mountedVolumeScanTimeout
        let result = await withCheckedContinuation { continuation in
            let race = ScanRaceResult(continuation)
            Task {
                do {
                    race.resume(.success(try await scanTask.value))
                } catch {
                    race.resume(.failure(error.localizedDescription))
                }
            }
            Task {
                let timeoutNanoseconds = UInt64(effectiveTimeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                scanTask.cancel()
                race.resume(.timeout)
            }
        }
        switch result {
        case .success(let files):
            return files
        case .timeout:
            throw ScanTimeoutError(path: url.path, seconds: effectiveTimeout)
        case .failure(let message):
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadUnknownError,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}
