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
        Group {
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
    }
}

// MARK: - In-App Notice History View
private struct InAppNoticeHistoryView: View {
    @State private var center = InAppNoticeCenter.shared

    var body: some View {
        VStack(spacing: 0) {
            historyHeader
            Divider()
            if center.history.isEmpty {
                Text("No recent messages")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(center.history) { notice in
                            historyRow(notice)
                            if notice.id != center.history.last?.id { Divider().padding(.leading, 42) }
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
        .frame(maxWidth: 520)
        .semanticSurface(cornerRadius: DesignTokens.Radius.card, isRaised: true)
        .accessibilityElement(children: .contain)
    }

    private var historyHeader: some View {
        HStack(spacing: DesignTokens.Spacing.group) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Recent Messages")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(center.history.count)/32")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button { center.hideHistory() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Close message history")
        }
        .padding(.leading, 13)
        .padding(.trailing, 9)
        .padding(.vertical, 9)
    }

    private func historyRow(_ notice: InAppNotice) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.group) {
            Image(systemName: notice.systemImage)
                .font(.system(size: 15, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(notice.tint)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notice.title)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(notice.createdAt, style: .time)
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(.tertiary)
                }
                if let message = notice.message {
                    Text(message)
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
    }
}

// MARK: - In-App Notice View
private struct InAppNoticeView: View {
    let notice: InAppNotice
    @State private var center = InAppNoticeCenter.shared

    var body: some View {
        HStack(alignment: notice.kind == .banner ? .top : .center, spacing: DesignTokens.Spacing.group) {
            Image(systemName: notice.systemImage)
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(notice.tint)
                .frame(width: 20, height: 20)
            noticeText
            if let actionTitle = notice.actionTitle {
                Button(actionTitle) { center.performAction(for: notice) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
            Button { center.dismiss(scope: notice.scope) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.leading, 13)
        .padding(.trailing, 9)
        .padding(.vertical, notice.kind == .banner ? 11 : 9)
        .frame(maxWidth: notice.kind == .banner ? 520 : 380, alignment: .leading)
        .semanticSurface(cornerRadius: DesignTokens.Radius.card, isRaised: true)
        .accessibilityElement(children: .contain)
    }

    private var noticeText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(notice.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            if let message = notice.message {
                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - In-App Notice Modifier
extension View {
    func inAppNoticeHost(scope: InAppNotice.Scope) -> some View {
        overlay { InAppNoticeHost(scope: scope) }
    }
}
