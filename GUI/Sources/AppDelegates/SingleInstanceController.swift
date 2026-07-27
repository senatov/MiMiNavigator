// SingleInstanceController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enforces one running MiMiNavigator process per user session.

import AppKit
import Darwin
import Foundation

// MARK: - Single Instance Controller
@MainActor
final class SingleInstanceController {
    static let shared = SingleInstanceController()
    private var lockFileDescriptor: Int32 = -1
    private let lockFilePath = "/private/tmp/Senatov.MiMiNavigator.instance.lock"
    private init() {}

    // MARK: - Acquire
    func acquire() -> Bool {
        guard lockFileDescriptor == -1 else { return true }
        let descriptor = open(lockFilePath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            log.error("[SingleInstance] cannot open lock file errno=\(errno)")
            return false
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }
        lockFileDescriptor = descriptor
        log.info("[SingleInstance] acquired process=\(ProcessInfo.processInfo.processIdentifier)")
        return true
    }

    // MARK: - Activate Existing Instance
    func activateExistingInstance() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let existingApplication = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.processIdentifier != currentProcessIdentifier && !$0.isTerminated }
        existingApplication?.activate(options: [.activateAllWindows])
        log.info("[SingleInstance] duplicate process=\(currentProcessIdentifier) existing=\(existingApplication?.processIdentifier ?? 0)")
    }

    // MARK: - Release
    func release() {
        guard lockFileDescriptor >= 0 else { return }
        flock(lockFileDescriptor, LOCK_UN)
        close(lockFileDescriptor)
        lockFileDescriptor = -1
        log.info("[SingleInstance] released")
    }
}
