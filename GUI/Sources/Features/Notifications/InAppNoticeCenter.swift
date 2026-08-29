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

    let id: UUID
    let createdAt: Date
    let kind: Kind
    let scope: Scope
    let title: String
    let message: String?
    let systemImage: String
    let tint: Color
    let actionTitle: String?
    let isActionAvailable: (() -> Bool)?
    let action: (() -> Void)?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: Kind,
        scope: Scope,
        title: String,
        message: String?,
        systemImage: String,
        tint: Color,
        actionTitle: String?,
        isActionAvailable: (() -> Bool)? = nil,
        action: (() -> Void)?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.scope = scope
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.actionTitle = actionTitle
        self.isActionAvailable = isActionAvailable
        self.action = action
    }
}

// MARK: - In-App Notice Center
@MainActor
@Observable
final class InAppNoticeCenter {
    private struct PersistedNotice: Codable {
        let id: UUID
        let createdAt: Date
        let isBanner: Bool
        let title: String
        let message: String?
        let systemImage: String
    }

    static let shared = InAppNoticeCenter()

    private(set) var visibleNotices: [InAppNotice.Scope: InAppNotice] = [:]
    private(set) var history: [InAppNotice] = []
    private(set) var isHistoryVisible = false
    private var queuedNotices: [InAppNotice.Scope: [InAppNotice]] = [:]
    private var dismissalTasks: [InAppNotice.Scope: Task<Void, Never>] = [:]
    private var performedActionIDs: Set<UUID> = []
    private let historyLimit = 32
    private let historyDefaultsKey = "inAppNotice.history.v1"

    private init() {
        restoreHistory()
    }

    // MARK: - Present Toast
    func showToast(
        _ title: String,
        message: String? = nil,
        scope: InAppNotice.Scope = .main,
        systemImage: String = "checkmark.circle.fill",
        tint: Color = .green,
        actionTitle: String? = nil,
        isActionAvailable: (() -> Bool)? = nil,
        action: (() -> Void)? = nil
    ) {
        present(InAppNotice(kind: .toast, scope: scope, title: title, message: message, systemImage: systemImage, tint: tint, actionTitle: actionTitle, isActionAvailable: isActionAvailable, action: action))
    }

    // MARK: - Present Banner
    func showBanner(
        title: String,
        message: String,
        scope: InAppNotice.Scope = .main,
        systemImage: String = "exclamationmark.triangle.fill",
        tint: Color = .orange,
        actionTitle: String? = nil,
        isActionAvailable: (() -> Bool)? = nil,
        action: (() -> Void)? = nil
    ) {
        present(InAppNotice(kind: .banner, scope: scope, title: title, message: message, systemImage: systemImage, tint: tint, actionTitle: actionTitle, isActionAvailable: isActionAvailable, action: action))
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
        guard isActionAvailable(for: notice) else { return }
        performedActionIDs.insert(notice.id)
        dismiss(scope: notice.scope)
        notice.action?()
    }

    func isActionAvailable(for notice: InAppNotice) -> Bool {
        !performedActionIDs.contains(notice.id) && (notice.isActionAvailable?() ?? (notice.action != nil))
    }

    // MARK: - History
    func toggleHistory() {
        isHistoryVisible.toggle()
    }

    func hideHistory() {
        isHistoryVisible = false
    }

    // MARK: - Queue Management
    private func present(_ notice: InAppNotice) {
        history.insert(notice, at: 0)
        if history.count > historyLimit {
            history.removeLast(history.count - historyLimit)
        }
        persistHistory()
        if visibleNotices[notice.scope] == nil {
            display(notice)
            return
        }
        queuedNotices[notice.scope, default: []].append(notice)
    }

    private func display(_ notice: InAppNotice) {
        visibleNotices[notice.scope] = notice
        let displayDuration: Duration = notice.kind == .toast ? .seconds(2.4) : .seconds(8)
        dismissalTasks[notice.scope] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: displayDuration)
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

    // MARK: - History Persistence
    private func persistHistory() {
        let persisted = history.map {
            PersistedNotice(
                id: $0.id,
                createdAt: $0.createdAt,
                isBanner: $0.kind == .banner,
                title: $0.title,
                message: $0.message,
                systemImage: $0.systemImage
            )
        }
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        UserDefaults.standard.set(data, forKey: historyDefaultsKey)
    }

    private func restoreHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyDefaultsKey),
              let persisted = try? JSONDecoder().decode([PersistedNotice].self, from: data)
        else { return }
        history = persisted.prefix(historyLimit).map {
            InAppNotice(
                id: $0.id,
                createdAt: $0.createdAt,
                kind: $0.isBanner ? .banner : .toast,
                scope: .main,
                title: $0.title,
                message: $0.message,
                systemImage: $0.systemImage,
                tint: restoredTint(for: $0.systemImage),
                actionTitle: nil,
                isActionAvailable: nil,
                action: nil
            )
        }
        log.info("[NoticeHistory] restored \(history.count) message(s)")
    }

    private func restoredTint(for systemImage: String) -> Color {
        if systemImage.contains("xmark") || systemImage.contains("octagon") { return .red }
        if systemImage.contains("exclamationmark") { return .orange }
        if systemImage.contains("stop") { return .secondary }
        return .green
    }
}
