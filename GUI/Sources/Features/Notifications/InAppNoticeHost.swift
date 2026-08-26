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
        Group {
            if center.history.isEmpty {
                NoticeCard(notice: nil, showsControls: false)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(center.history) { notice in
                            NoticeCard(notice: notice, showsControls: false)
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
        NoticeCard(notice: notice, showsControls: true)
    }
}

// MARK: - Notice Card
private struct NoticeCard: View {
    let notice: InAppNotice?
    let showsControls: Bool
    @State private var center = InAppNoticeCenter.shared

    var body: some View {
        HStack(alignment: notice?.kind == .banner ? .top : .center, spacing: 11) {
            Image(systemName: notice?.systemImage ?? "clock.arrow.circlepath")
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(notice?.tint ?? .secondary)
                .frame(width: 20, height: 20)
            noticeText
            if showsControls, let notice, let actionTitle = notice.actionTitle {
                Button(actionTitle) { center.performAction(for: notice) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
            if showsControls, let notice {
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
        .frame(maxWidth: showsControls && notice?.kind != .banner ? 380 : 520, alignment: .leading)
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
                Text(notice?.title ?? "No recent messages")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if !showsControls, let notice {
                    Text(notice.createdAt, format: .dateTime.day().month().year().hour().minute().second())
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let message = notice?.message {
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
