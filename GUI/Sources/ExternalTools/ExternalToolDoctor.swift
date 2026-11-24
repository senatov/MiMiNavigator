// ExternalToolDoctor.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Diagnostics and repair flow for external command-line tools.

import AppKit
import ExternalToolsKit
import FileModelKit
import Foundation

// MARK: - ExternalToolHealthKind

enum ExternalToolHealthKind: String, Codable, Sendable {
    case ok
    case missing
    case incomplete
    case broken

    var isUsable: Bool { self == .ok }
}

// MARK: - ExternalToolHealthReport

struct ExternalToolHealthReport: Identifiable, Sendable {
    let tool: ExternalTool
    let kind: ExternalToolHealthKind
    let summary: String
    let details: String
    let checkedAt: Date

    var id: String { tool.id }
    var canRepair: Bool { tool.brewFormula != nil && !tool.isSystemTool }
}

// MARK: - ExternalToolDoctor

@MainActor
@Observable
final class ExternalToolDoctor {
    static let shared = ExternalToolDoctor()

    private(set) var reports: [String: ExternalToolHealthReport] = [:]
    private(set) var isChecking = false
    private(set) var isRepairing = false

    private init() {}

    // MARK: - Public API

    func diagnoseAll() async {
        isChecking = true
        for tool in ExternalToolCatalog.allTools {
            reports[tool.id] = await diagnose(tool)
        }
        isChecking = false
        ExternalToolRegistry.shared.refreshAll()
    }

    func diagnose(_ tool: ExternalTool) async -> ExternalToolHealthReport {
        guard let path = tool.resolvedPath else {
            return report(tool: tool, kind: .missing, summary: "Not installed", details: tool.installHint)
        }
        if tool.id == ExternalToolCatalog.ffmpeg.id {
            return await diagnoseFFmpeg(tool: tool, path: path)
        }
        if tool.id == ExternalToolCatalog.ffprobe.id {
            return await diagnoseVersionedTool(tool: tool, path: path, arguments: ["-version"])
        }
        if tool.id == ExternalToolCatalog.gifski.id {
            return await diagnoseVersionedTool(tool: tool, path: path, arguments: ["--version"])
        }
        if tool.id == ExternalToolCatalog.sevenZip.id {
            return await diagnoseSevenZip(tool: tool, path: path)
        }
        return report(tool: tool, kind: .ok, summary: "Available", details: path)
    }

    func ensureReady(toolID: String, context: String) async -> Bool {
        guard let tool = ExternalToolCatalog.allTools.first(where: { $0.id == toolID }) else { return true }
        let current = await diagnose(tool)
        reports[tool.id] = current
        guard !current.kind.isUsable else { return true }
        guard await promptRepair(tool: tool, report: current, context: context) else { return false }
        let repaired = await diagnose(tool)
        reports[tool.id] = repaired
        ExternalToolRegistry.shared.refreshSingle(tool.id)
        return repaired.kind.isUsable
    }

    func ensureReady(conversionTool: ConversionTool, context: String) async -> Bool {
        switch conversionTool {
        case .imageIO:
            return true
        case .ffmpeg, .lottieAndFFmpeg:
            return await ensureReady(toolID: ExternalToolCatalog.ffmpeg.id, context: context)
        case .gifski:
            let ffmpegReady = await ensureReady(toolID: ExternalToolCatalog.ffmpeg.id, context: context)
            let gifskiReady = await ensureReady(toolID: ExternalToolCatalog.gifski.id, context: context)
            return ffmpegReady && gifskiReady
        }
    }

    func promptRepair(tool: ExternalTool, report: ExternalToolHealthReport, context: String) async -> Bool {
        let canRepair = ExternalToolCatalog.brew.isInstalled && report.canRepair
        let buttons = canRepair
            ? [report.kind == .missing ? "Install Now" : "Repair Now", "Copy Command", "Cancel"]
            : ["Copy Command", "Cancel"]
        let choice = await ErrorAlertService.choose(
            title: "\(tool.name) Needs Repair",
            message: """
                \(context)

                Status: \(report.summary)

                MiMiNavigator can run:
                \(repairCommand(for: tool, report: report))
                """,
            buttons: buttons,
            style: .warning
        )
        if choice == (canRepair ? 1 : 0) {
            copyCommand(repairCommand(for: tool, report: report))
            return false
        }
        guard canRepair, choice == 0 else { return false }
        return await repair(tool, reinstall: report.kind != .missing)
    }

    func repairMissingAndBrokenTools() async {
        isRepairing = true
        for tool in ExternalToolCatalog.optionalTools {
            let current: ExternalToolHealthReport
            if let cached = reports[tool.id] {
                current = cached
            } else {
                current = await diagnose(tool)
            }
            reports[tool.id] = current
            if current.canRepair && !current.kind.isUsable {
                _ = await repair(tool, reinstall: current.kind != .missing)
                reports[tool.id] = await diagnose(tool)
            }
        }
        isRepairing = false
        ExternalToolRegistry.shared.refreshAll()
    }

    // MARK: - Diagnostics

    private func diagnoseFFmpeg(tool: ExternalTool, path: String) async -> ExternalToolHealthReport {
        let encoders = await run(path, arguments: ["-hide_banner", "-encoders"])
        guard encoders.exitCode == 0 else {
            return report(tool: tool, kind: .broken, summary: "ffmpeg failed", details: encoders.combinedOutput)
        }
        let required = ["h264_videotoolbox", "hevc_videotoolbox", "prores_ks", "libvpx-vp9", "libmp3lame", "libopus"]
        let missing = required.filter { !encoders.combinedOutput.contains($0) }
        if !missing.isEmpty {
            return report(tool: tool, kind: .incomplete, summary: "Missing codecs: \(missing.joined(separator: ", "))", details: encoders.combinedOutput)
        }
        return report(tool: tool, kind: .ok, summary: "Media presets ready", details: path)
    }

    private func diagnoseSevenZip(tool: ExternalTool, path: String) async -> ExternalToolHealthReport {
        let result = await run(path, arguments: ["i"])
        guard result.exitCode == 0 else {
            return report(tool: tool, kind: .broken, summary: "7-Zip failed", details: result.combinedOutput)
        }
        let hasFormats = result.combinedOutput.contains("7z") && result.combinedOutput.contains("rar")
        guard hasFormats else {
            return report(tool: tool, kind: .incomplete, summary: "Archive formats list looks incomplete", details: result.combinedOutput)
        }
        return report(tool: tool, kind: .ok, summary: "Archive formats ready", details: path)
    }

    private func diagnoseVersionedTool(tool: ExternalTool, path: String, arguments: [String]) async -> ExternalToolHealthReport {
        let result = await run(path, arguments: arguments)
        guard result.exitCode == 0 else {
            return report(tool: tool, kind: .broken, summary: "\(tool.name) failed", details: result.combinedOutput)
        }
        return report(tool: tool, kind: .ok, summary: "Available", details: result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func report(tool: ExternalTool, kind: ExternalToolHealthKind, summary: String, details: String) -> ExternalToolHealthReport {
        ExternalToolHealthReport(tool: tool, kind: kind, summary: summary, details: details, checkedAt: Date())
    }

    // MARK: - Repair

    private func repair(_ tool: ExternalTool, reinstall: Bool) async -> Bool {
        guard let brewPath = ExternalToolCatalog.brew.resolvedPath, let formula = tool.brewFormula else {
            copyCommand(tool.installHint)
            return false
        }
        isRepairing = true
        let verb = reinstall ? "reinstall" : "install"
        log.info("[ExternalTools] \(verb) \(formula)")
        let result = await installInTerminal(brewPath: brewPath, verb: verb, formula: formula)
        isRepairing = false
        showRepairResult(tool: tool, success: result.exitCode == 0, output: result.combinedOutput)
        return result.exitCode == 0
    }

    private func showRepairResult(tool: ExternalTool, success: Bool, output: String) {
        if success {
            InAppNoticeCenter.shared.showToast("\(tool.name) is ready", scope: .settings, systemImage: "checkmark.circle.fill", tint: .green)
        } else {
            InAppNoticeCenter.shared.showBanner(
                title: "\(tool.name) Repair Failed",
                message: String(output.prefix(1200)),
                scope: .settings,
                systemImage: "xmark.octagon.fill",
                tint: .red
            )
        }
    }

    private func repairCommand(for tool: ExternalTool, report: ExternalToolHealthReport) -> String {
        guard let formula = tool.brewFormula else { return tool.installHint }
        let verb = report.kind == .missing ? "install" : "reinstall"
        if let brewPath = ExternalToolCatalog.brew.resolvedPath {
            let prefix = URL(fileURLWithPath: brewPath).deletingLastPathComponent().deletingLastPathComponent()
            let owner = try? FileManager.default.attributesOfItem(atPath: prefix.path)[.ownerAccountName] as? String
            if let owner, owner != NSUserName() { return "brew as-brew-user \(verb) \(formula)" }
        }
        return "brew \(verb) \(formula)"
    }

    private func copyCommand(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        log.info("[ExternalTools] copied '\(command)' to clipboard")
    }

    // MARK: - Install in Terminal
    private func installInTerminal(brewPath: String, verb: String, formula: String) async -> ToolProcessResult {
        let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("miminavigator-tool-install-\(UUID().uuidString)", isDirectory: true)
        let scriptURL = directory.appendingPathComponent("install.command")
        let statusURL = directory.appendingPathComponent("status.txt")
        let protocolURL = directory.appendingPathComponent("install.log")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try installScript(brewPath: brewPath, verb: verb, formula: formula, statusURL: statusURL, protocolURL: protocolURL)
                .write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                return ToolProcessResult(exitCode: -1, combinedOutput: "Terminal could not be found.")
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            let opened: Bool = await withCheckedContinuation { continuation in
                NSWorkspace.shared.open([scriptURL], withApplicationAt: terminalURL, configuration: configuration) { _, error in
                    continuation.resume(returning: error == nil)
                }
            }
            guard opened else { return ToolProcessResult(exitCode: -1, combinedOutput: "Terminal could not be opened.") }
            for _ in 0..<3600 {
                if Task.isCancelled { return ToolProcessResult(exitCode: -1, combinedOutput: "Installation was cancelled.") }
                if let status = try? String(contentsOf: statusURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
                    let protocolText = (try? String(contentsOf: protocolURL, encoding: .utf8)) ?? ""
                    let message: String
                    switch status {
                    case "needs-owner":
                        message = "Homebrew belongs to another account. Ask its owner or an administrator to install \(formula)."
                    case "done":
                        message = protocolText
                    default:
                        message = "Installation log: \(protocolURL.path)\n\(protocolText)"
                    }
                    return ToolProcessResult(exitCode: status == "done" ? 0 : 1, combinedOutput: message)
                }
                try? await Task.sleep(for: .seconds(1))
            }
            return ToolProcessResult(exitCode: -1, combinedOutput: "Installation is still running in Terminal. Log: \(protocolURL.path)")
        } catch {
            return ToolProcessResult(exitCode: -1, combinedOutput: error.localizedDescription)
        }
    }

    // MARK: - Installation Script
    private func installScript(brewPath: String, verb: String, formula: String, statusURL: URL, protocolURL: URL) -> String {
        #"""
        #!/bin/zsh
        set -e
        set -o pipefail
        status_file=\#(Self.shellQuote(statusURL.path))
        protocol_file=\#(Self.shellQuote(protocolURL.path))
        failure_reason=failed
        TRAPEXIT() {
            local result=$?
            if (( result == 0 )); then
                print -r -- done > "$status_file"
            else
                print -r -- "$failure_reason" > "$status_file"
            fi
        }
        brew=\#(Self.shellQuote(brewPath))
        brew_prefix=${brew%/bin/brew}
        brew_owner=$(/usr/bin/stat -f %Su "$brew_prefix")
        if [[ "$brew_owner" == root ]]; then
            print -u2 'The Homebrew prefix is owned by root and needs administrator repair.'
            failure_reason=needs-owner
            exit 1
        fi
        brew_command=(/usr/bin/env)
        if [[ "$brew_owner" != "$(/usr/bin/id -un)" ]]; then
            if [[ " $(/usr/bin/id -Gn) " != *" admin "* ]]; then
                print -u2 "Homebrew belongs to $brew_owner. Ask its owner or an administrator to install the tool."
                failure_reason=needs-owner
                exit 1
            fi
            log_dir=$(/usr/bin/sudo -H -u "$brew_owner" /usr/bin/mktemp -d /tmp/miminavigator-homebrew-logs.XXXXXX)
            brew_command=(/usr/bin/sudo -H -u "$brew_owner" /usr/bin/env)
        else
            log_dir=$(/usr/bin/mktemp -d /tmp/miminavigator-homebrew-logs.XXXXXX)
        fi
        brew_command+=("HOMEBREW_LOGS=$log_dir" "$brew")
        "${brew_command[@]}" \#(verb) \#(formula) 2>&1 | /usr/bin/tee "$protocol_file"
        """#
    }

    // MARK: - Shell Quoting
    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    // MARK: - Process

    private nonisolated func run(_ executablePath: String, arguments: [String]) async -> ToolProcessResult {
        await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = output
            do {
                try process.run()
                process.waitUntilExit()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                return ToolProcessResult(exitCode: process.terminationStatus, combinedOutput: text)
            } catch {
                return ToolProcessResult(exitCode: -1, combinedOutput: error.localizedDescription)
            }
        }.value
    }
}

// MARK: - ToolProcessResult

private struct ToolProcessResult: Sendable {
    let exitCode: Int32
    let combinedOutput: String
}
