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
    case failure(any Error)
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
    func resume(_ result: ScanRaceOutput, beforeResume: () -> Void = {}) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()
        beforeResume()
        continuation.resume(returning: result)
    }
}

// MARK: - Scan Timeout Race
enum ScanTimeoutRace {
    // MARK: - Run
    static func run(
        _ scanTask: Task<[CustomFile], Error>,
        url: URL,
        timeout: TimeInterval,
        waitForTimeout: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) async throws -> [CustomFile] {
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let race = ScanRaceResult(continuation)
                let timeoutTask = Task {
                    do { try await waitForTimeout(timeout) } catch { return }
                    race.resume(.timeout, beforeResume: { scanTask.cancel() })
                }
                Task {
                    do {
                        race.resume(.success(try await scanTask.value))
                    } catch {
                        race.resume(.failure(error))
                    }
                    timeoutTask.cancel()
                }
            }
        } onCancel: {
            scanTask.cancel()
        }
        switch result {
        case .success(let files):
            return files
        case .timeout:
            throw ScanTimeoutError(path: url.path, seconds: timeout)
        case .failure(let error):
            throw error
        }
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
        try await ScanTimeoutRace.run(scanTask, url: url, timeout: timeout ?? mountedVolumeScanTimeout)
    }
}
