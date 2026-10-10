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
        if let summary = gitStatusStore.summary(for: currentURL), let root = gitStatusStore.repositoryRoot(for: currentURL) {
            Button {
                GitClientRegistry.shared.openPreferred(repository: root)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(summaryTint(summary))
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
            }
            .buttonStyle(.plain)
            .help("\(summaryHelp(summary)). Click to open preferred Git client; right-click for more.")
            .contextMenu { gitClientMenu(repository: root) }
        }
    }

    private func summaryTint(_ summary: GitDirectorySummary) -> Color {
        if summary.conflicted > 0 { return Color(nsColor: .systemRed) }
        if summary.modified > 0 { return Color(nsColor: .systemOrange) }
        if summary.untracked > 0 { return Color(nsColor: .systemGreen) }
        return Color(nsColor: .secondaryLabelColor)
    }

    @ViewBuilder
    private func summaryBadge(_ label: String, count: Int, tint: Color) -> some View {
        if count > 0 {
            Text("\(label) \(count)")
                .font(.system(size: 9.5, weight: .medium, design: .default))
                .foregroundStyle(tint)
        }
    }

    private func summaryHelp(_ summary: GitDirectorySummary) -> String {
        "Git: \(summary.modified) modified, \(summary.untracked) untracked, \(summary.ignored) ignored, \(summary.conflicted) conflicted"
    }
}
