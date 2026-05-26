// ProgressPanelAppearance.swift
// MiMiNavigator
//
// Created by Claude on 19.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persisted appearance for ProgressPanel — bg color, log font/color, panel size.
//   Stored in ~/.mimi/progress_appearance.json. Editable via Settings → Progress Panel.

import AppKit
import SwiftUI

// MARK: - Progress Panel Appearance

@MainActor
@Observable
final class ProgressPanelAppearance {

    static let shared = ProgressPanelAppearance()

    private let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress_appearance.json")
    }()

    // MARK: - Defaults (warm-yellow terminal style)

    static let defaultBgHex          = "#FFF8DC"   // cornsilk — warm yellow
    static let defaultBorderHex      = "#C8B88A"   // warm tan border
    static let defaultLogFontName    = "Menlo"
    static let defaultLogFontSize    = 10.5
    static let defaultLogColorHex    = "#0A1A6B"   // dark navy blue
    static let defaultTitleColorHex  = "#8B1A1A"   // dark reddish
    static let defaultStatusColorHex = "#0A1A6B"   // dark navy
    static let defaultWidth: CGFloat = 560
    static let defaultHeight: CGFloat = 236
    static let defaultMinWidth: CGFloat = 380
    static let defaultMinHeight: CGFloat = 168

    // MARK: - Published properties

    var hexBackground: String       = defaultBgHex
    var hexBorder: String           = defaultBorderHex
    var logFontName: String         = defaultLogFontName
    var logFontSize: Double         = defaultLogFontSize
    var hexLogColor: String         = defaultLogColorHex
    var hexTitleColor: String       = defaultTitleColorHex
    var hexStatusColor: String      = defaultStatusColorHex
    var panelWidth: CGFloat         = defaultWidth
    var panelHeight: CGFloat        = defaultHeight
    var framesByOperation: [String: ProgressPanelFrame] = [:]

    // MARK: - Computed NSColor/NSFont accessors

    var bgColor: NSColor       { Self.nsColor(hex: hexBackground) ?? NSColor(calibratedRed: 1, green: 0.97, blue: 0.86, alpha: 1) }
    var borderColor: NSColor   { Self.nsColor(hex: hexBorder) ?? .separatorColor }
    var logFont: NSFont        { NSFont(name: logFontName, size: CGFloat(logFontSize)) ?? .monospacedSystemFont(ofSize: CGFloat(logFontSize), weight: .light) }
    var logColor: NSColor      { Self.nsColor(hex: hexLogColor) ?? .textColor }
    var titleFont: NSFont      { .systemFont(ofSize: 13, weight: .light) }
    var titleColor: NSColor    { Self.nsColor(hex: hexTitleColor) ?? .labelColor }
    var statusFont: NSFont     { .systemFont(ofSize: 11.5, weight: .regular) }
    var statusColor: NSColor   { Self.nsColor(hex: hexStatusColor) ?? .secondaryLabelColor }

    /// Bridge: hex string → NSColor via SwiftUI Color(hex:)
    private static func nsColor(hex: String) -> NSColor? {
        guard let c = Color(hex: hex) else { return nil }
        return NSColor(c)
    }

    // MARK: - Init

    private init() { load() }

    // MARK: - Persistence

    private struct StoredData: Codable {
        var hexBackground: String?
        var hexBorder: String?
        var logFontName: String?
        var logFontSize: Double?
        var hexLogColor: String?
        var hexTitleColor: String?
        var hexStatusColor: String?
        var panelWidth: Double?
        var panelHeight: Double?
        var framesByOperation: [String: ProgressPanelFrame]?
    }

    func save() {
        let data = StoredData(
            hexBackground: hexBackground,
            hexBorder: hexBorder,
            logFontName: logFontName,
            logFontSize: logFontSize,
            hexLogColor: hexLogColor,
            hexTitleColor: hexTitleColor,
            hexStatusColor: hexStatusColor,
            panelWidth: Double(panelWidth),
            panelHeight: Double(panelHeight),
            framesByOperation: framesByOperation
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try SafeJSONStorage.writeCodable(data, to: fileURL, label: "progress_appearance.json", encoder: encoder)
            log.debug("[ProgressAppearance] saved to \(fileURL.path)")
        } catch {
            log.error("[ProgressAppearance] save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            log.debug("[ProgressAppearance] no saved prefs, using defaults")
            return
        }
        do {
            let d = try SafeJSONStorage.loadCodable(
                from: fileURL,
                as: StoredData.self,
                label: "progress_appearance.json"
            )
            if let v = d.hexBackground   { hexBackground = v }
            if let v = d.hexBorder       { hexBorder = v }
            if let v = d.logFontName     { logFontName = v }
            if let v = d.logFontSize     { logFontSize = v }
            if let v = d.hexLogColor     { hexLogColor = v }
            if let v = d.hexTitleColor   { hexTitleColor = v }
            if let v = d.hexStatusColor  { hexStatusColor = v }
            if let v = d.panelWidth      { panelWidth = CGFloat(v) }
            if let v = d.panelHeight     { panelHeight = CGFloat(v) }
            if let v = d.framesByOperation { framesByOperation = v }
            log.debug("[ProgressAppearance] loaded: \(Int(panelWidth))x\(Int(panelHeight)) font=\(logFontName)@\(logFontSize)")
        } catch {
            log.error("[ProgressAppearance] load failed: \(error)")
            SafeJSONStorage.moveUnreadablePrimaryAside(fileURL: fileURL, label: "progress_appearance.json")
            save()
        }
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        hexBackground = Self.defaultBgHex
        hexBorder = Self.defaultBorderHex
        logFontName = Self.defaultLogFontName
        logFontSize = Self.defaultLogFontSize
        hexLogColor = Self.defaultLogColorHex
        hexTitleColor = Self.defaultTitleColorHex
        hexStatusColor = Self.defaultStatusColorHex
        panelWidth = Self.defaultWidth
        panelHeight = Self.defaultHeight
        framesByOperation = [:]
        save()
    }

    // MARK: - Size Persistence

    func updateSize(width: CGFloat, height: CGFloat) {
        panelWidth = width
        panelHeight = height
        save()
    }

    // MARK: - Operation Frame Persistence

    func frame(for operationKey: String) -> ProgressPanelFrame? {
        framesByOperation[operationKey]
    }

    func updateFrame(_ frame: ProgressPanelFrame, for operationKey: String) {
        framesByOperation[operationKey] = frame
        panelWidth = frame.width
        panelHeight = frame.height
        save()
    }
}

// MARK: - Progress Panel Frame
struct ProgressPanelFrame: Codable, Equatable {
    var relativeX: Double
    var relativeY: Double
    var width: Double
    var height: Double
    var lineCount: Int?
}
