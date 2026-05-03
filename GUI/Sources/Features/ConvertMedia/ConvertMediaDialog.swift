// ConvertMediaDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Convert Media dialog — glass-panel style matching Network Neighborhood.

import AppKit
import FileModelKit
import SwiftUI

struct ConvertMediaDialog: View {
    let file: CustomFile
    let onConvert: (MediaFormat, URL) -> Void
    let onCancel: () -> Void
    var onNavigate: ((URL) -> Void)?
    var onDismiss: (() -> Void)?

    @State var targetFormat: MediaFormat
    @State var outputName: String
    @State var outputDir: String
    @State var availableFormats: [MediaFormat]
    @FocusState var isNameFieldFocused: Bool
    @State var configuredWindowNumber: Int?
    @State var frameSaveWorkItem: DispatchWorkItem?
    @State var windowObserverTokens: [NSObjectProtocol] = []

    let sourceFormat: MediaFormat?

    enum Layout {
        static let minWidth: CGFloat = 400
        static let idealWidth: CGFloat = 460
        static let minHeight: CGFloat = 300
        static let outerCornerRadius: CGFloat = 14
        static let sectionCornerRadius: CGFloat = 12
        static let hPad: CGFloat = 12
        static let compactHPad: CGFloat = 10
        static let sectionHeaderHorizontalPadding: CGFloat = 12
        static let sectionHeaderTopPadding: CGFloat = 10
        static let sectionHeaderBottomPadding: CGFloat = 4
        static let frameAutosaveDelay: TimeInterval = 0.25
        static let panelTintOpacity: Double = 0.10
        static let headerTintOpacity: Double = 0.12
        static let sectionTintOpacity: Double = 0.08
        static let borderOpacity: Double = 0.20
        static let chipCornerRadius: CGFloat = 6
        static let borderLineWidth: CGFloat = 0.8
    }

    enum WindowState {
        static let frameKey = "convertMediaDialogFrame"
        static let frameChangedNotification = NSWindow.didMoveNotification
        static let resizeChangedNotification = NSWindow.didEndLiveResizeNotification
        static let becomeMainNotification = NSWindow.didBecomeMainNotification
    }

    struct StoredFrame: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    init(file: CustomFile, onConvert: @escaping (MediaFormat, URL) -> Void, onCancel: @escaping () -> Void) {
        self.file = file
        self.onConvert = onConvert
        self.onCancel = onCancel

        let fileExtension = file.urlValue.pathExtension.lowercased()
        let detectedSourceFormat = MediaFormat.from(extension: fileExtension)
        let targetFormats = detectedSourceFormat.map { MediaFormat.targets(for: $0) } ?? []
        let baseName = (file.nameStr as NSString).deletingPathExtension
        let outputDirectory = file.urlValue.deletingLastPathComponent().path

        sourceFormat = detectedSourceFormat
        _availableFormats = State(initialValue: targetFormats)
        _targetFormat = State(initialValue: targetFormats.first ?? .mp4)
        _outputName = State(initialValue: baseName)
        _outputDir = State(initialValue: outputDirectory)
    }

    var outputURL: URL {
        URL(fileURLWithPath: outputDir)
            .appendingPathComponent(outputName)
            .appendingPathExtension(targetFormat.fileExtension)
    }

    var isValid: Bool {
        !outputName.isEmpty && !availableFormats.isEmpty && sourceFormat != nil
    }

    var toolInfo: String {
        guard let sourceFormat else { return "" }
        let tool = MediaFormat.requiredTool(from: sourceFormat, to: targetFormat)
        if tool == .gifski {
            let gifskiOK = FileManager.default.isExecutableFile(atPath: ConversionTool.gifskiPath)
            let ffmpegOK = FileManager.default.isExecutableFile(atPath: ConversionTool.ffmpegPath)
            if gifskiOK && ffmpegOK {
                return "gifski + ffmpeg ✅"
            }
            if ffmpegOK {
                return "gifski ❌ (fallback: ffmpeg)"
            }
            return "gifski ❌  ffmpeg ❌"
        }
        let status = tool.isAvailable ? "✅" : "❌ not installed"
        return "\(tool.rawValue) \(status)"
    }

    var body: some View {
        VStack(spacing: 10) {
            headerBar
            sourceCard
            targetCard
            outputCard
            toolStatusBar
            buttonBar
        }
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.idealWidth, minHeight: Layout.minHeight)
        .padding(.top, 10)
        .background(panelBackground)
        .glassEffect(.regular)
        .overlay(panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .higAutoFocusTextField()
        .background(windowConfigurator)
        .onAppear {
            isNameFieldFocused = true
        }
        .onDisappear {
            cleanupWindowState()
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
}
