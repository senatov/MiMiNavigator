// DiffToolRegistry.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Registry of external diff tools.
//   Built-in presets (KDiff3, Beyond Compare, FileMerge, Kaleidoscope…) + user-added tools.
//   Active tool is persisted in UserDefaults. Tool list persisted as JSON.
//   launchDiffTool() in MiMiNavigatorApp reads resolveTool(for:) instead of hardcoded paths.

import Foundation

// MARK: - DiffToolRegistry

@MainActor
@Observable
final class DiffToolRegistry {

    static let shared = DiffToolRegistry()

    private let listKey   = "DiffToolRegistry.tools.v1"
    private let activeKey = "DiffToolRegistry.activeID"

    private(set) var tools: [DiffTool] = []

    private(set) var activeToolID = "auto"

    private init() {
        activeToolID = MiMiDefaults.shared.string(forKey: activeKey) ?? "auto"
        load()
    }

    // MARK: - Resolve

    /// Returns best available tool for the given scope.
    /// Respects user's explicit selection; falls back to priority list.
    func resolveTool(for scope: DiffToolScope) -> DiffTool? {
        let available = tools.filter { $0.isEnabled && $0.isInstalled && supports($0, scope) }

        if activeToolID != "auto",
           let pick = available.first(where: { $0.id == activeToolID }) {
            return pick
        }
        // Auto priority
        let priority: [String]
        switch scope {
        case .filesOnly: priority = ["kdiff3","bc","kscope","araxis","intellij","filemerge","bbedit"]
        case .dirsOnly, .both: priority = ["kdiff3","bc","kscope","araxis","intellij"]
        }
        for id in priority {
            if let t = available.first(where: { $0.id == id }) { return t }
        }
        return available.first
    }

    private func supports(_ t: DiffTool, _ scope: DiffToolScope) -> Bool {
        t.scope == .both || t.scope == scope
    }

    // MARK: - Mutations

    func add(_ tool: DiffTool) {
        guard !tools.contains(where: { $0.id == tool.id }) else { return }
        tools.append(tool)
        save()
        log.info("[DiffToolRegistry] added '\(tool.name)'")
    }

    func remove(id: String) {
        guard let t = tools.first(where: { $0.id == id }), !t.isBuiltIn else { return }
        tools.removeAll { $0.id == id }
        if activeToolID == id { setActiveTool(id: "auto") }
        save()
    }

    func update(_ tool: DiffTool) {
        if let i = tools.firstIndex(where: { $0.id == tool.id }) { tools[i] = tool }
        save()
    }

    func toggleEnabled(id: String) {
        if let i = tools.firstIndex(where: { $0.id == id }) { tools[i].isEnabled.toggle() }
        if activeToolID == id, tools.first(where: { $0.id == id })?.isEnabled == false {
            setActiveTool(id: "auto")
        }
        save()
    }

    // MARK: - Active Tool
    func setActiveTool(id: String) {
        guard id == "auto" || tools.contains(where: { $0.id == id && $0.isInstalled }) else { return }
        if let index = tools.firstIndex(where: { $0.id == id }), !tools[index].isEnabled {
            tools[index].isEnabled = true
            save()
        }
        activeToolID = id
        MiMiDefaults.shared.set(id, forKey: activeKey)
        log.info("[DiffToolRegistry] active tool='\(id)'")
    }

    // MARK: - Refresh Availability
    func refreshAvailability() {
        tools = Array(tools)
        log.debug("[DiffToolRegistry] refreshed tool availability")
    }

    func moveUp(id: String) {
        guard let i = tools.firstIndex(where: { $0.id == id }), i > 0 else { return }
        tools.swapAt(i, i - 1); save()
    }

    func moveDown(id: String) {
        guard let i = tools.firstIndex(where: { $0.id == id }), i < tools.count - 1 else { return }
        tools.swapAt(i, i + 1); save()
    }

    // MARK: - Persist

    private func load() {
        if let data = MiMiDefaults.shared.data(forKey: listKey),
           var saved = try? JSONDecoder().decode([DiffTool].self, from: data) {
            saved.removeAll { $0.id == "diffmerge" }
            for builtin in DiffTool.allBuiltIns {
                if !saved.contains(where: { $0.id == builtin.id }) { saved.append(builtin) }
            }
            tools = saved
        } else {
            tools = DiffTool.allBuiltIns
        }
        if activeToolID == "diffmerge" {
            activeToolID = "kdiff3"
            MiMiDefaults.shared.set(activeToolID, forKey: activeKey)
        }
        if activeToolID != "auto", let index = tools.firstIndex(where: { $0.id == activeToolID && $0.isInstalled }) {
            tools[index].isEnabled = true
        }
        log.info("[DiffToolRegistry] loaded \(tools.count) tools, active='\(activeToolID)'")
    }

    func save() {
        if let data = try? JSONEncoder().encode(tools) {
            MiMiDefaults.shared.set(data, forKey: listKey)
        }
    }
}
