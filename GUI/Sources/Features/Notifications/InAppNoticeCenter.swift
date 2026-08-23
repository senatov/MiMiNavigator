// InAppNoticeCenter.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Queued in-app toast and error banner presentation for app windows.

import SwiftUI

// MARK: - In-App Notice
struct InAppNotice: Identifiable {
    enum Kind: Equatable {
        case toast
        case banner
    }

    enum Scope: Hashable {
        case main
        case connectToServer
        case findFiles
        case multiRename
        case networkNeighborhood
        case settings
        case mediaConvert
    }

    let id = UUID()
    let kind: Kind
    let scope: Scope
    let title: String
    let message: String?
    let systemImage: String
    let tint: Color
    let actionTitle: String?
    let action: (() -> Void)?
}

// MARK: - In-App Notice Center
@MainActor
@Observable
final class InAppNoticeCenter {
    static let shared = InAppNoticeCenter()

    private(set) var visibleNotices: [InAppNotice.Scope: InAppNotice] = [:]
    private var queuedNotices: [InAppNotice.Scope: [InAppNotice]] = [:]
    private var dismissalTasks: [InAppNotice.Scope: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Present Toast
    func showToast(
        _ title: String,
        scope: InAppNotice.Scope = .main,
        systemImage: String = "checkmark.circle.fill",
        tint: Color = .green,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        present(InAppNotice(kind: .toast, scope: scope, title: title, message: nil, systemImage: systemImage, tint: tint, actionTitle: actionTitle, action: action))
    }

    // MARK: - Present Banner
    func showBanner(
        title: String,
        message: String,
        scope: InAppNotice.Scope = .main,
        systemImage: String = "exclamationmark.triangle.fill",
        tint: Color = .orange,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        present(InAppNotice(kind: .banner, scope: scope, title: title, message: message, systemImage: systemImage, tint: tint, actionTitle: actionTitle, action: action))
    }

    // MARK: - Present Error
    func showError(
        title: String,
        message: String,
        scope: InAppNotice.Scope = .main,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        showBanner(title: title, message: message, scope: scope, systemImage: "xmark.circle.fill", tint: .red, actionTitle: actionTitle, action: action)
    }

    // MARK: - Current Notice
    func notice(for scope: InAppNotice.Scope) -> InAppNotice? {
        visibleNotices[scope]
    }

    // MARK: - Dismiss
    func dismiss(scope: InAppNotice.Scope) {
        dismissalTasks[scope]?.cancel()
        dismissalTasks[scope] = nil
        visibleNotices[scope] = nil
        showNextIfNeeded(scope: scope)
    }

    // MARK: - Clear Scope
    func clear(scope: InAppNotice.Scope) {
        dismissalTasks[scope]?.cancel()
        dismissalTasks[scope] = nil
        visibleNotices[scope] = nil
        queuedNotices[scope] = nil
    }

    // MARK: - Perform Action
    func performAction(for notice: InAppNotice) {
        dismiss(scope: notice.scope)
        notice.action?()
    }

    // MARK: - Queue Management
    private func present(_ notice: InAppNotice) {
        if visibleNotices[notice.scope] == nil {
            display(notice)
            return
        }
        queuedNotices[notice.scope, default: []].append(notice)
    }

    private func display(_ notice: InAppNotice) {
        visibleNotices[notice.scope] = notice
        guard notice.kind == .toast else { return }
        dismissalTasks[notice.scope] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.dismiss(scope: notice.scope)
        }
    }

    private func showNextIfNeeded(scope: InAppNotice.Scope) {
        guard var queue = queuedNotices[scope], !queue.isEmpty else { return }
        let next = queue.removeFirst()
        queuedNotices[scope] = queue
        display(next)
    }
}
