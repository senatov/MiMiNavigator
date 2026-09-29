// FeedbackReporter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 31.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Prepares privacy-filtered feedback for the public Blogger comments page.

import AppKit
import Foundation

// MARK: - Feedback Reporter
enum FeedbackReporter {
    static let feedbackURL = "https://miminavi.blogspot.com/2026/05/blog-post.html#comments"

    // MARK: - Open Feedback
    @MainActor
    static func openBlogComments() {
        openReview(title: "Feedback", message: "Describe the problem or suggestion above the diagnostic information.")
    }

    // MARK: - Review Error Report
    @MainActor
    static func reviewError(title: String, message: String) {
        openReview(title: title, message: message)
    }

    // MARK: - Open Review
    @MainActor
    static func openReview(title: String, message: String) {
        let report = DiagnosticReportBuilder.make(title: title, message: message)
        DiagnosticReportPresenter.shared.show(report)
    }

    // MARK: - Copy and Open Blogger
    @MainActor
    static func copyAndOpenBlog(_ report: String) {
        guard !report.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              report.count <= DiagnosticReportBuilder.maximumCommentCharacters else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        Task {
            let filled = await Task.detached(priority: .userInitiated) {
                BloggerCommentPrefiller.fill(report)
            }.value
            if !filled, let url = URL(string: BloggerCommentPrefiller.commentURL) {
                NSWorkspace.shared.open(url)
            }
            InAppNoticeCenter.shared.showToast(
                filled ? "Comment Ready" : "Comment Copied",
                message: filled ? "Review the Blogger comment and click Publish when ready." : "Blogger could not be filled automatically. Paste the copied text, then publish it yourself.",
                systemImage: "doc.on.clipboard.fill",
                tint: .blue,
                displayDuration: .seconds(8)
            )
            log.info("[Feedback] Blogger comment \(filled ? "filled" : "opened without autofill"); publication left to user")
        }
    }
}
