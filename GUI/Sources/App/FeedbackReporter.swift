// FeedbackReporter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 31.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Opens feedback channels and prepares optional diagnostics.

import AppKit
import Foundation

// MARK: - Feedback Reporter
enum FeedbackReporter {
    private static let feedbackURL = "https://miminavi.blogspot.com/2026/05/blog-post.html#comments"
    private static let supportEmail = "senatov@icloud.com"

    // MARK: - Open Feedback
    @MainActor
    static func openBlogComments() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportTemplate(), forType: .string)
        guard let url = URL(string: feedbackURL) else {
            log.error("[Feedback] invalid feedback URL")
            return
        }
        NSWorkspace.shared.open(url)
        log.info("[Feedback] opened feedback comments and copied template")
    }

    // MARK: - Send Diagnostics
    @MainActor
    static func sendDiagnosticsEmail() {
        Task {
            do {
                let archiveURL = try await Task.detached(priority: .userInitiated) {
                    try makeDiagnosticsArchive()
                }.value
                composeDiagnosticsEmail(archiveURL: archiveURL)
                log.info("[Feedback] prepared diagnostics email: \(archiveURL.path)")
            } catch {
                log.error("[Feedback] failed to prepare diagnostics: \(error.localizedDescription)")
                showDiagnosticsError(error)
            }
        }
    }

    // MARK: - Report Template
    private static func reportTemplate() -> String {
        """
        MiMiNavigator feedback

        App version: \(appVersionString())
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)

        Problem or suggestion:

        """
    }

    // MARK: - Email Body
    private static func emailBody() -> String {
        """
        MiMiNavigator diagnostics

        App version: \(appVersionString())
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)

        Problem or suggestion:

        """
    }

    // MARK: - App Version String
    private static func appVersionString() -> String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?):
            return "\(short) (\(build))"
        case let (short?, nil):
            return short
        case let (nil, build?):
            return "build \(build)"
        default:
            return "unknown"
        }
    }

    // MARK: - Make Diagnostics Archive
    private static func makeDiagnosticsArchive() throws -> URL {
        let fileManager = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let baseURL = fileManager.temporaryDirectory.appendingPathComponent("MiMiNavigatorFeedback-\(stamp)", isDirectory: true)
        let archiveURL = fileManager.temporaryDirectory.appendingPathComponent("MiMiNavigatorDiagnostics-\(stamp).zip")
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try metadataText().write(to: baseURL.appendingPathComponent("diagnostics.txt"), atomically: true, encoding: .utf8)
        try copyLogFiles(to: baseURL)
        try runZip(sourceURL: baseURL, archiveURL: archiveURL)
        try? fileManager.removeItem(at: baseURL)
        return archiveURL
    }

    // MARK: - Metadata Text
    private static func metadataText() -> String {
        """
        MiMiNavigator diagnostics
        App version: \(appVersionString())
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Date: \(Date())
        """
    }

    // MARK: - Copy Log Files
    private static func copyLogFiles(to directoryURL: URL) throws {
        let fileManager = FileManager.default
        let candidates = [AppLogger.logFileURL, Optional(AppLogger.tmpLogFileURL)].compactMap { $0 }
        for sourceURL in candidates where fileManager.fileExists(atPath: sourceURL.path) {
            let destinationURL = directoryURL.appendingPathComponent(sourceURL.lastPathComponent)
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    // MARK: - Run Zip
    private static func runZip(sourceURL: URL, archiveURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", sourceURL.path, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    // MARK: - Compose Diagnostics Email
    @MainActor
    private static func composeDiagnosticsEmail(archiveURL: URL) {
        guard let service = NSSharingService(named: .composeEmail) else {
            NSWorkspace.shared.activateFileViewerSelecting([archiveURL])
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(supportEmail, forType: .string)
            showEmailFallback()
            return
        }
        service.recipients = [supportEmail]
        service.subject = "MiMiNavigator feedback"
        service.perform(withItems: [emailBody(), archiveURL])
    }

    // MARK: - Show Diagnostics Error
    @MainActor
    private static func showDiagnosticsError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Cannot prepare diagnostics"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Show Email Fallback
    @MainActor
    private static func showEmailFallback() {
        let alert = NSAlert()
        alert.messageText = "Diagnostics archive created"
        alert.informativeText = "Mail compose is not available. The archive was revealed in Finder and the support email address was copied to the clipboard."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
