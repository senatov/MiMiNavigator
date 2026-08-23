// SelectionStatusBar+Git.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact read-only Git summary for a file panel directory.

import SwiftUI

// MARK: - Git Summary Section
extension SelectionStatusBar {
    @ViewBuilder
    var gitSummarySection: some View {
        if let summary = gitStatusStore.summary(for: currentURL) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                if summary.isEmpty {
                    Text("Clean")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                } else {
                    summaryBadge("M", count: summary.modified, tint: Color(nsColor: .systemOrange))
                    summaryBadge("?", count: summary.untracked, tint: Color(nsColor: .systemGreen))
                    summaryBadge("I", count: summary.ignored, tint: Color(nsColor: .secondaryLabelColor))
                    summaryBadge("!", count: summary.conflicted, tint: Color(nsColor: .systemRed))
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .help(summaryHelp(summary))
        }
    }

    @ViewBuilder
    private func summaryBadge(_ label: String, count: Int, tint: Color) -> some View {
        if count > 0 {
            Text("\(label) \(count)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    private func summaryHelp(_ summary: GitDirectorySummary) -> String {
        "Git: \(summary.modified) modified, \(summary.untracked) untracked, \(summary.ignored) ignored, \(summary.conflicted) conflicted"
    }
}
