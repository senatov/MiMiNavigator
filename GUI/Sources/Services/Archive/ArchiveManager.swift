// ArchiveManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: UI-facing archive coordinator — password prompts and extraction flow.

import Foundation

// MARK: - Archive Manager
/// Keeps UI interaction in the application while ArchiveKit owns session state and temporary files.
actor ArchiveManager {

    static let shared = ArchiveManager()

    private let sessionStore = ArchiveSessionStore()
    private let fm = FileManager.default

    private init() {}

    // MARK: - Password Helpers
    private func storedArchivePassword() async -> String? {
        await MainActor.run {
            ArchivePasswordStore.shared.loadPassword()
        }
    }

    private func saveArchivePasswordIfNeeded(_ password: String?) async {
        guard let password, !password.isEmpty else { return }
        await MainActor.run {
            ArchivePasswordStore.shared.savePassword(password)
        }
    }

    private func promptArchivePassword(for archiveURL: URL, wrongPassword: Bool) async -> String? {
        await ErrorAlertService.promptSecureText(
            title: wrongPassword ? "Wrong Archive Password" : "Archive Password Required",
            message: wrongPassword
                ? "The password for \(archiveURL.lastPathComponent) is incorrect. Enter a new password to continue."
                : "\(archiveURL.lastPathComponent) is password-protected. Enter the password to continue."
        )
    }

    private func resetTempDirectory(_ tempDirectory: URL) throws {
        if fm.fileExists(atPath: tempDirectory.path) {
            try fm.removeItem(at: tempDirectory)
        }
        try fm.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func isPasswordProtectedFormat(_ format: ArchiveFormat) -> Bool {
        switch format {
        case .zip, .sevenZip, .sevenZipGeneric:
            return true
        default:
            return false
        }
    }

    private func extractArchive(
        archiveURL: URL,
        format: ArchiveFormat,
        to tempDir: URL,
        password: String?,
        onProgress: ArchiveExtractor.ProgressLine?,
        processHandle: ActiveArchiveProcess?
    ) async throws {
        try await ArchiveExtractor.extract(
            archiveURL: archiveURL,
            format: format,
            to: tempDir,
            password: password,
            onProgress: onProgress,
            processHandle: processHandle
        )
    }

    private func extractWithPasswordFlow(
        archiveURL: URL,
        format: ArchiveFormat,
        to tempDir: URL,
        explicitPassword: String?,
        onProgress: ArchiveExtractor.ProgressLine?,
        processHandle: ActiveArchiveProcess?
    ) async throws {
        let initialPassword: String?
        if let explicitPassword {
            initialPassword = explicitPassword
        } else if isPasswordProtectedFormat(format) {
            initialPassword = await storedArchivePassword()
        } else {
            initialPassword = nil
        }

        do {
            try await extractArchive(
                archiveURL: archiveURL,
                format: format,
                to: tempDir,
                password: initialPassword,
                onProgress: onProgress,
                processHandle: processHandle
            )
            await saveArchivePasswordIfNeeded(initialPassword)
            return
        } catch {
            guard let archiveError = error as? ArchiveManagerError,
                  archiveError.isPasswordRelated,
                  isPasswordProtectedFormat(format)
            else {
                throw error
            }
        }

        var attempt = 0
        var wrongPassword = true
        while attempt < 3 {
            attempt += 1
            let promptedPassword = await promptArchivePassword(for: archiveURL, wrongPassword: wrongPassword)
            guard let promptedPassword else {
                throw ArchiveManagerError.operationCancelled
            }

            do {
                try resetTempDirectory(tempDir)
                try await extractArchive(
                    archiveURL: archiveURL,
                    format: format,
                    to: tempDir,
                    password: promptedPassword,
                    onProgress: onProgress,
                    processHandle: processHandle
                )
                await saveArchivePasswordIfNeeded(promptedPassword)
                return
            } catch {
                if let archiveError = error as? ArchiveManagerError, archiveError.isPasswordRelated {
                    wrongPassword = true
                    continue
                }
                throw error
            }
        }

        throw ArchiveManagerError.wrongPassword
    }

    // MARK: - Open Helpers
    private func detectFormat(for archiveURL: URL) throws -> ArchiveFormat {
        guard let format = ArchiveFormatDetector.detect(url: archiveURL) else {
            throw ArchiveManagerError.unsupportedFormat(archiveURL.pathExtension)
        }
        return format
    }

    // MARK: - Open

    func openArchive(
        at archiveURL: URL,
        password: String? = nil,
        onProgress: ArchiveExtractor.ProgressLine? = nil,
        processHandle: ActiveArchiveProcess? = nil
    ) async throws -> URL {
        log.debug("[ArchiveManager] openArchive: \(archiveURL.lastPathComponent) hasPassword=\(password != nil) pwdLen=\(password?.count ?? 0)")
        switch await sessionStore.reserveOpen(at: archiveURL) {
            case .existing(let tempDirectory):
                return tempDirectory
            case .wait:
                return try await sessionStore.waitForOpening(at: archiveURL)
            case .owner:
                break
        }
        var tempDirectory: URL?
        do {
            let format = try detectFormat(for: archiveURL)
            let tempDir = try await sessionStore.makeTempDirectory()
            tempDirectory = tempDir
            try await extractWithPasswordFlow(
                archiveURL: archiveURL,
                format: format,
                to: tempDir,
                explicitPassword: password,
                onProgress: onProgress,
                processHandle: processHandle
            )
            _ = await sessionStore.registerOpened(archiveURL: archiveURL, format: format, tempDirectory: tempDir)
            log.info("[ArchiveManager] Opened: \(archiveURL.lastPathComponent), refCount=1")
            return tempDir
        } catch {
            log.error("[ArchiveManager] openArchive failed: \(error)")
            await sessionStore.cancelOpen(at: archiveURL, tempDirectory: tempDirectory)
            throw error
        }
    }

    // MARK: - Close

    /// Close archive session. Only removes tmp when refCount reaches 0.
    func closeArchive(at archiveURL: URL, repackIfDirty: Bool) async throws {
        try await sessionStore.closeArchive(at: archiveURL, repackIfDirty: repackIfDirty)
    }

    // MARK: - Dirty

    @discardableResult
    func markDirty(archivePath: String) async -> Bool {
        await sessionStore.markDirty(archivePath: archivePath)
    }

    @discardableResult
    func markDirtyByTempPath(_ tempPath: String) async -> Bool {
        let marked = await sessionStore.markDirtyByTempPath(tempPath)
        if !marked { log.warning("[ArchiveManager] markDirtyByTempPath ignored — session not found: \(tempPath)") }
        return marked
    }

    func isDirty(archiveURL: URL) async -> Bool {
        await sessionStore.isDirty(archiveURL: archiveURL)
    }

    // MARK: - Query

    func sessionForArchive(at archiveURL: URL) async -> ArchiveSession? {
        await sessionStore.sessionForArchive(at: archiveURL)
    }

    func sessionForPath(_ path: String) async -> ArchiveSession? {
        await sessionStore.sessionForPath(path)
    }

    func isInsideArchive(path: String) async -> Bool {
        await sessionStore.sessionForPath(path) != nil
    }

    func archiveURL(forTempPath tempPath: String) async -> URL? {
        await sessionStore.sessionForPath(tempPath)?.archiveURL
    }

    // MARK: - Cleanup

    func cleanup() async {
        await sessionStore.cleanup()
    }
}
