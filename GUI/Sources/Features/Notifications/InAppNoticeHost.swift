// InAppNoticeHost.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: SwiftUI host and HIG-aligned presentation for queued in-app notices.

import SwiftUI

// MARK: - In-App Notice Host
struct InAppNoticeHost: View {
    let scope: InAppNotice.Scope
    @State private var center = InAppNoticeCenter.shared

    var body: some View {
        ZStack(alignment: .top) {
            if scope == .main && center.isHistoryVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { center.hideHistory() }
            }
            if scope == .main && center.isHistoryVisible {
                InAppNoticeHistoryView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let notice = center.notice(for: scope) {
                InAppNoticeView(notice: notice)
                    .id(notice.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.24), value: center.isHistoryVisible)
        .animation(.snappy(duration: 0.24), value: center.notice(for: scope)?.id)
        .padding(.top, DesignTokens.Spacing.group)
        .padding(.horizontal, DesignTokens.Spacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(center.notice(for: scope) != nil || (scope == .main && center.isHistoryVisible))
        .onExitCommand {
            if scope == .main && center.isHistoryVisible {
                center.hideHistory()
            }
        }
    }
}

// MARK: - In-App Notice History View
private struct InAppNoticeHistoryView: View {
    @State private var center = InAppNoticeCenter.shared

    var body: some View {
        Group {
            if center.history.isEmpty {
                NoticeCard(notice: nil, showsControls: false, historyNumber: nil)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(center.history.enumerated()), id: \.element.id) { index, notice in
                            NoticeCard(notice: notice, showsControls: true, historyNumber: index + 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.visible)
                .frame(maxHeight: 360)
            }
        }
        .frame(maxWidth: 520)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - In-App Notice View
private struct InAppNoticeView: View {
    let notice: InAppNotice
    @State private var center = InAppNoticeCenter.shared

    var body: some View {
        NoticeCard(notice: notice, showsControls: true, historyNumber: nil)
    }
}

// MARK: - Notice Card
private struct NoticeCard: View {
    let notice: InAppNotice?
    let showsControls: Bool
    let historyNumber: Int?
    @State private var center = InAppNoticeCenter.shared
    @State private var colorStore = ColorThemeStore.shared
    @State private var isActionHovered = false

    var body: some View {
        HStack(alignment: notice?.kind == .banner ? .top : .center, spacing: 11) {
            Image(systemName: notice?.systemImage ?? "clock.arrow.circlepath")
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(notice?.tint ?? .secondary)
                .frame(width: 20, height: 20)
            noticeText
            if historyNumber == nil, let notice, let actionTitle = notice.actionTitle, center.isActionAvailable(for: notice) {
                Button(actionTitle) { center.performAction(for: notice) }
                    .buttonStyle(
                        DownToolbarGlassButtonStyle(
                            isHovered: isActionHovered,
                            horizontalPadding: 8,
                            verticalPadding: 4,
                            raised: true
                        )
                    )
                    .onHover { isActionHovered = $0 }
                    .keyboardShortcut(.defaultAction)
            }
            if showsControls, historyNumber == nil, let notice {
                Button { center.dismiss(scope: notice.scope) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 9)
        .padding(.vertical, notice?.kind == .banner ? 11 : 9)
        .frame(maxWidth: historyNumber == nil && notice?.kind != .banner ? 380 : 520, alignment: .leading)
        .background(
            Color(#colorLiteral(red: 1, green: 0.969, blue: 0.82, alpha: 0.96)),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.black.opacity(0.20), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
    }

    private var noticeText: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(numberedTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorStore.activeTheme.panelText)
                Spacer()
                if historyNumber != nil, let notice {
                    Text(notice.createdAt, format: .dateTime.day().month().year().hour().minute().second())
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let message = notice?.message {
                messageText(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var numberedTitle: String {
        guard let historyNumber else { return notice?.title ?? "No recent messages" }
        return "\(historyNumber). \(notice?.title ?? "No recent messages")"
    }

    @ViewBuilder
    private func messageText(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(message.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                let value = String(line)
                if value.hasPrefix("From: ") || value.hasPrefix("To: ") || value.hasPrefix("Removed: ") {
                    let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(parts.first ?? ""):")
                            .foregroundStyle(colorStore.activeTheme.panelText)
                        Text(parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "")
                            .foregroundStyle(Color(#colorLiteral(red: 0.039, green: 0.102, blue: 0.42, alpha: 1)))
                            .textSelection(.enabled)
                    }
                } else {
                    Text(value)
                        .foregroundStyle(colorStore.activeTheme.panelText)
                }
            }
        }
        .font(.system(size: 11, weight: .light))
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - In-App Notice Modifier
extension View {
    func inAppNoticeHost(scope: InAppNotice.Scope) -> some View {
        overlay { InAppNoticeHost(scope: scope) }
    }
}
