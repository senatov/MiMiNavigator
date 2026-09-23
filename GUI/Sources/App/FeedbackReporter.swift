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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        guard let url = URL(string: feedbackURL) else {
            log.error("[Feedback] invalid feedback URL")
            return
        }
        NSWorkspace.shared.open(url)
        InAppNoticeCenter.shared.showToast(
            "Report Copied",
            message: "Paste it into the Blogger comment and publish only if you still agree.",
            systemImage: "doc.on.clipboard.fill",
            tint: .blue,
            displayDuration: .seconds(8)
        )
        log.info("[Feedback] opened Blogger after explicit diagnostic review")
    }
}
