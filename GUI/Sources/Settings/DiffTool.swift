// DiffTool.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: External diff-tool model, discovery, arguments, and built-in presets.

import Foundation

// MARK: - Diff Tool
struct DiffTool: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var appPath: String
    var arguments: String
    var scope: DiffToolScope
    var isBuiltIn: Bool
    var isEnabled: Bool

    var processName: String {
        if id == "intellij", intellijInstallPath?.hasSuffix(".app") == false {
            return URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        }
        return URL(fileURLWithPath: displayPath).deletingPathExtension().lastPathComponent
    }

    var resolvedBinary: String {
        if id == "intellij", let launcher = intellijLauncherPath { return launcher }
        guard let installedPath else { return appPath }
        guard installedPath.hasSuffix(".app") else { return installedPath }
        let directory = "\(installedPath)/Contents/MacOS"
        for name in ["bcomp", "ksdiff"] {
            let path = "\(directory)/\(name)"
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        let appName = URL(fileURLWithPath: installedPath).deletingPathExtension().lastPathComponent
        let candidate = "\(directory)/\(appName)"
        if FileManager.default.fileExists(atPath: candidate) { return candidate }
        if let first = (try? FileManager.default.contentsOfDirectory(atPath: directory))?.first {
            return "\(directory)/\(first)"
        }
        return candidate
    }

    var isInstalled: Bool {
        installedPath != nil
    }

    var displayPath: String {
        installedPath ?? appPath
    }

    private var installedPath: String? {
        if id == "intellij" { return intellijInstallPath }
        if FileManager.default.fileExists(atPath: appPath) { return appPath }
        guard appPath.hasSuffix(".app") else { return nil }
        let appName = URL(fileURLWithPath: appPath).lastPathComponent
        return Self.applicationCandidates(named: appName).first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Application Candidates
    private static func applicationCandidates(named appName: String) -> [String] {
        let fileManager = FileManager.default
        let roots = fileManager.urls(for: .applicationDirectory, in: .allDomainsMask)
        var paths = roots.flatMap { root in
            [
                root.appendingPathComponent(appName).path,
                root.appendingPathComponent("Utilities").appendingPathComponent(appName).path,
            ]
        }
        paths.append("\(fileManager.homeDirectoryForCurrentUser.path)/Applications/\(appName)")
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    private var intellijInstallPath: String? {
        intellijCandidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private var intellijLauncherPath: String? {
        let candidates = [
            "/usr/local/bin/idea",
            "/opt/homebrew/bin/idea",
            "\(NSHomeDirectory())/bin/idea",
        ]
        if let launcher = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return launcher
        }
        guard let app = intellijInstallPath, app.hasSuffix(".app") else { return nil }
        let directory = "\(app)/Contents/MacOS"
        return ["idea", "IntelliJ IDEA"]
            .map { "\(directory)/\($0)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private var intellijCandidates: [String] {
        let appNames = ["IntelliJ IDEA CE.app", "IntelliJ IDEA.app", "IntelliJ IDEA Ultimate.app"]
        return appNames.flatMap(Self.applicationCandidates) + [
            "/usr/local/bin/idea",
            "/opt/homebrew/bin/idea",
        ]
    }

    // MARK: - Build Arguments
    func buildArgs(left: String, right: String) -> [String] {
        let expanded = arguments
            .replacingOccurrences(of: "%left", with: left)
            .replacingOccurrences(of: "%right", with: right)
        return tokenize(expanded)
    }

    // MARK: - Tokenize
    private func tokenize(_ value: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var isQuoted = false
        var quote: Character = "\""
        for character in value {
            if isQuoted {
                if character == quote { isQuoted = false } else { current.append(character) }
            } else if character == "\"" || character == "'" {
                isQuoted = true
                quote = character
            } else if character == " " {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}

// MARK: - Built-in Presets
extension DiffTool {
    static let kdiff3 = DiffTool(
        id: "kdiff3", name: "KDiff3",
        appPath: "/Applications/kdiff3.app",
        arguments: "\"%left\" \"%right\"",
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
    static let intellij = DiffTool(
        id: "intellij", name: "IntelliJ IDEA",
        appPath: "/Applications/IntelliJ IDEA CE.app",
        arguments: "diff \"%left\" \"%right\"",
        scope: .both, isBuiltIn: true, isEnabled: true)
    static let allBuiltIns: [DiffTool] = [
        .kdiff3, .beyondCompare, .fileMerge,
        .kaleidoscope, .araxis, .bbEdit, .meld, .intellij,
    ]
}
