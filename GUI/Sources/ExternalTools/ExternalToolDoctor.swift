// ExternalToolDoctor.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Diagnostics and repair flow for external command-line tools.

import AppKit
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
        let response = showRepairAlert(tool: tool, report: report, context: context)
        if response == .alertSecondButtonReturn {
            copyCommand(tool.installHint)
            return false
        }
        guard response == .alertFirstButtonReturn else { return false }
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
        let result = await run(brewPath, arguments: [verb, formula])
        isRepairing = false
        showRepairResult(tool: tool, success: result.exitCode == 0, output: result.combinedOutput)
        return result.exitCode == 0
    }

    private func showRepairAlert(tool: ExternalTool, report: ExternalToolHealthReport, context: String) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\(tool.name) Needs Repair"
        alert.informativeText = """
            \(context)

            Status: \(report.summary)

            MiMiNavigator can run:
            \(repairCommand(for: tool, report: report))
            """
        if ExternalToolCatalog.brew.isInstalled && report.canRepair {
            alert.addButton(withTitle: report.kind == .missing ? "Install Now" : "Repair Now")
        }
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal()
    }

    private func showRepairResult(tool: ExternalTool, success: Bool, output: String) {
        let alert = NSAlert()
        alert.alertStyle = success ? .informational : .warning
        alert.messageText = success ? "\(tool.name) Ready" : "\(tool.name) Repair Failed"
        alert.informativeText = success ? "\(tool.name) was installed or repaired successfully." : String(output.prefix(1200))
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func repairCommand(for tool: ExternalTool, report: ExternalToolHealthReport) -> String {
        guard let formula = tool.brewFormula else { return tool.installHint }
        let verb = report.kind == .missing ? "install" : "reinstall"
        return "brew \(verb) \(formula)"
    }

    private func copyCommand(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        log.info("[ExternalTools] copied '\(command)' to clipboard")
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
