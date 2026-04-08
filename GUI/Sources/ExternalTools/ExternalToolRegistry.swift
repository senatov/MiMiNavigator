// ExternalToolRegistry.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Runtime registry — caches tool availability with TTL.
//   Singleton, main-actor isolated. UI binds to `statuses` for live updates.
//   Lazy check on first access, background refresh every 30s.

import Foundation


// MARK: - ToolStatus

struct ToolStatus: Identifiable, Sendable {
    let tool: ExternalTool
    let isAvailable: Bool
    let resolvedPath: String?
    let checkedAt: Date

    var id: String { tool.id }
    var isExpired: Bool { Date().timeIntervalSince(checkedAt) > ExternalToolRegistry.cacheTTL }
}


// MARK: - ExternalToolRegistry

@MainActor
@Observable
final class ExternalToolRegistry {

    static let shared = ExternalToolRegistry()
    nonisolated static let cacheTTL: TimeInterval = 30

    private(set) var statuses: [ToolStatus] = []
    private(set) var brewAvailable: Bool = false
    private var lastFullCheck: Date = .distantPast


    private init() {
        refreshAll()
    }


    // MARK: - Public API

    func isAvailable(_ toolID: String) -> Bool {
        statusFor(toolID)?.isAvailable ?? false
    }


    func statusFor(_ toolID: String) -> ToolStatus? {
        if let s = statuses.first(where: { $0.id == toolID }), !s.isExpired {
            return s
        }
        refreshAll()
        return statuses.first { $0.id == toolID }
    }


    func refreshAll() {
        let now = Date()
        guard now.timeIntervalSince(lastFullCheck) > 2 else { return }
        lastFullCheck = now
        brewAvailable = ExternalToolCatalog.brew.isInstalled
        statuses = ExternalToolCatalog.allTools.map { tool in
            ToolStatus(
                tool: tool,
                isAvailable: tool.isInstalled,
                resolvedPath: tool.resolvedPath,
                checkedAt: now)
        }
        log.info("[ExternalToolRegistry] refreshed \(statuses.count) tools, brew=\(brewAvailable)")
    }


    func refreshSingle(_ toolID: String) {
        guard let tool = ExternalToolCatalog.allTools.first(where: { $0.id == toolID }) else { return }
        let now = Date()
        let fresh = ToolStatus(tool: tool, isAvailable: tool.isInstalled, resolvedPath: tool.resolvedPath, checkedAt: now)
        if let idx = statuses.firstIndex(where: { $0.id == toolID }) {
            statuses[idx] = fresh
        } else {
            statuses.append(fresh)
        }
    }
}
