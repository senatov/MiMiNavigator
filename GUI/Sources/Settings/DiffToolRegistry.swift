// DiffToolRegistry.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Registry of external diff tools.
//   Built-in presets (DiffMerge, Beyond Compare, FileMerge, Kaleidoscope…) + user-added tools.
//   Active tool is persisted in UserDefaults. Tool list persisted as JSON.
//   launchDiffTool() in MiMiNavigatorApp reads resolveTool(for:) instead of hardcoded paths.

import AppKit
import Foundation

// MARK: - DiffToolScope

/// What kinds of comparison the tool supports
enum DiffToolScope: String, Codable, CaseIterable, Identifiable {
    case filesOnly = "files"
    case dirsOnly  = "dirs"
    case both      = "both"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .filesOnly: "Files only"
        case .dirsOnly:  "Directories only"
        case .both:      "Files & Dirs"
        }
    }
}

// MARK: - DiffTool

struct DiffTool: Identifiable, Codable, Equatable {
    var id:        String          // stable key — "diffmerge", "bc", uuid for user tools
    var name:      String
    var appPath:   String          // .app bundle or CLI binary
    var arguments: String          // %left / %right placeholders
    var scope:     DiffToolScope
    var isBuiltIn: Bool            // built-ins can be disabled but not deleted
    var isEnabled: Bool

    // MARK: Computed

    var processName: String {
        URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
    }

    /// Real binary inside .app, or the path as-is for CLIs
    var resolvedBinary: String {
        guard appPath.hasSuffix(".app") else { return appPath }
        let appName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        let candidate = "\(appPath)/Contents/MacOS/\(appName)"
        if FileManager.default.fileExists(atPath: candidate) { return candidate }
        // Scan MacOS dir for any executable
        let dir = "\(appPath)/Contents/MacOS"
        if let first = (try? FileManager.default.contentsOfDirectory(atPath: dir))?.first {
            return "\(dir)/\(first)"
        }
        return candidate
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: appPath)
    }

    /// Expand %left / %right into real argument array
    func buildArgs(left: String, right: String) -> [String] {
        let expanded = arguments
            .replacingOccurrences(of: "%left",  with: left)
            .replacingOccurrences(of: "%right", with: right)
        return tokenize(expanded)
    }

    // simple tokenizer: split on unquoted spaces
    private func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var cur = ""
        var inQ = false
        var qc: Character = "\""
        for ch in s {
            if inQ { if ch == qc { inQ = false } else { cur.append(ch) } }
            else if ch == "\"" || ch == "'" { inQ = true; qc = ch }
            else if ch == " " { if !cur.isEmpty { tokens.append(cur); cur = "" } }
            else { cur.append(ch) }
        }
        if !cur.isEmpty { tokens.append(cur) }
        return tokens
    }
}

// MARK: - Built-in presets

extension DiffTool {

    static let diffMerge = DiffTool(
        id: "diffmerge", name: "DiffMerge",
        appPath: "/Applications/DiffMerge.app",
        arguments: "--nosplash \"%left\" \"%right\"",
        scope: .both, isBuiltIn: true, isEnabled: true)

    static let beyondCompare = DiffTool(
        id: "bc", name: "Beyond Compare",
        appPath: "/Applications/Beyond Compare.app",
        arguments: "\"%left\" \"%right\"",
        scope: .both, isBuiltIn: true, isEnabled: true)

    static let fileMerge = DiffTool(
        id: "filemerge", name: "FileMerge (Xcode)",
        appPath: "/usr/bin/opendiff",
        arguments: "\"%left\" \"%right\"",
        scope: .filesOnly, isBuiltIn: true, isEnabled: true)

    static let kaleidoscope = DiffTool(
        id: "kscope", name: "Kaleidoscope",
        appPath: "/Applications/Kaleidoscope 3.app",
        arguments: "\"%left\" \"%right\"",
        scope: .both, isBuiltIn: true, isEnabled: true)

    static let araxis = DiffTool(
        id: "araxis", name: "Araxis Merge",
        appPath: "/Applications/Araxis Merge.app",
        arguments: "\"%left\" \"%right\"",
        scope: .both, isBuiltIn: true, isEnabled: true)

    static let bbEdit = DiffTool(
        id: "bbedit", name: "BBEdit",
        appPath: "/Applications/BBEdit.app",
        arguments: "\"%left\" \"%right\"",
        scope: .filesOnly, isBuiltIn: true, isEnabled: true)

    static let meld = DiffTool(
        id: "meld", name: "Meld",
        appPath: "/Applications/Meld.app",
        arguments: "\"%left\" \"%right\"",
        scope: .both, isBuiltIn: true, isEnabled: true)

    static let allBuiltIns: [DiffTool] = [
        .diffMerge, .beyondCompare, .fileMerge,
        .kaleidoscope, .araxis, .bbEdit, .meld,
    ]
}

// MARK: - DiffToolRegistry

@MainActor
@Observable
final class DiffToolRegistry {

    static let shared = DiffToolRegistry()

    private let listKey   = "DiffToolRegistry.tools.v1"
    private let activeKey = "DiffToolRegistry.activeID"

    private(set) var tools: [DiffTool] = []

    var activeToolID: String {
        get { UserDefaults.standard.string(forKey: activeKey) ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: activeKey) }
    }

    private init() { load() }

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
        case .filesOnly: priority = ["diffmerge","bc","kscope","araxis","filemerge","bbedit"]
        case .dirsOnly, .both: priority = ["diffmerge","bc","kscope","araxis"]
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
        if activeToolID == id { activeToolID = "auto" }
        save()
    }

    func update(_ tool: DiffTool) {
        if let i = tools.firstIndex(where: { $0.id == tool.id }) { tools[i] = tool }
        save()
    }

    func toggleEnabled(id: String) {
        if let i = tools.firstIndex(where: { $0.id == id }) { tools[i].isEnabled.toggle() }
        save()
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
        if let data = UserDefaults.standard.data(forKey: listKey),
           var saved = try? JSONDecoder().decode([DiffTool].self, from: data) {
            for builtin in DiffTool.allBuiltIns {
                if !saved.contains(where: { $0.id == builtin.id }) { saved.append(builtin) }
            }
            tools = saved
        } else {
            tools = DiffTool.allBuiltIns
        }
        log.info("[DiffToolRegistry] loaded \(tools.count) tools, active='\(activeToolID)'")
    }

    func save() {
        if let data = try? JSONEncoder().encode(tools) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }
}
