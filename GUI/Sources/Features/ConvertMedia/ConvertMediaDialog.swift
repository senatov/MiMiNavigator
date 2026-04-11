// ConvertMediaDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Convert Media dialog — shows source file, target format picker,
//   output path and filename. Styled like Network Neighborhood panel.

import FileModelKit
import SwiftUI

struct ConvertMediaDialog: View {
    let file: CustomFile
    let onConvert: (MediaFormat, URL) -> Void
    let onCancel: () -> Void

    @State private var targetFormat: MediaFormat
    @State private var outputName: String
    @State private var outputDir: String
    @State private var availableFormats: [MediaFormat]
    @FocusState private var isNameFieldFocused: Bool

    private let sourceFormat: MediaFormat?

    private enum Layout {
        static let minWidth: CGFloat = 440
        static let cornerRadius: CGFloat = 14
        static let sectionRadius: CGFloat = 12
        static let hPad: CGFloat = 14
    }

    private enum Glass {
        static let borderOpacity: Double = 0.14
        static let tintOpacity: Double = 0.07
    }

    init(file: CustomFile, onConvert: @escaping (MediaFormat, URL) -> Void, onCancel: @escaping () -> Void) {
        self.file = file
        self.onConvert = onConvert
        self.onCancel = onCancel
        let ext = file.urlValue.pathExtension.lowercased()
        let src = MediaFormat.from(extension: ext)
        self.sourceFormat = src
        let targets = src.map { MediaFormat.targets(for: $0) } ?? []
        self._availableFormats = State(initialValue: targets)
        self._targetFormat = State(initialValue: targets.first ?? .mp4)
        let baseName = (file.nameStr as NSString).deletingPathExtension
        self._outputName = State(initialValue: baseName)
        self._outputDir = State(initialValue: file.urlValue.deletingLastPathComponent().path)
    }

    private var outputURL: URL {
        URL(fileURLWithPath: outputDir)
            .appendingPathComponent(outputName)
            .appendingPathExtension(targetFormat.fileExtension)
    }

    private var isValid: Bool {
        !outputName.isEmpty && !availableFormats.isEmpty && sourceFormat != nil
    }

    private var toolInfo: String {
        guard let src = sourceFormat else { return "" }
        let tool = MediaFormat.requiredTool(from: src, to: targetFormat)
        let status = tool.isAvailable ? "✅" : "❌ not installed"
        return "\(tool.rawValue) \(status)"
    }

    var body: some View {
        VStack(spacing: 12) {
            headerSection
            Divider()
            sourceSection
            Divider()
            targetSection
            Divider()
            outputSection
            Divider()
            toolStatusSection
            buttonSection
        }
        .frame(minWidth: Layout.minWidth)
        .padding(Layout.hPad)
        .background(panelBackground)
        .overlay(panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .higAutoFocusTextField()
        .onAppear { isNameFieldFocused = true }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Convert Media")
                    .font(.headline)
                Text(file.urlValue.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }

    // MARK: - Source info

    private var sourceSection: some View {
        HStack(spacing: 8) {
            Image(systemName: sourceFormat?.systemImage ?? "doc")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Source").font(.caption).foregroundStyle(.secondary)
                Text(file.nameStr)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let fmt = sourceFormat {
                Text(fmt.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.12)))
            }
        }
    }

    // MARK: - Target format picker

    private var targetSection: some View {
        HStack(spacing: 8) {
            Image(systemName: targetFormat.systemImage)
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Convert to").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $targetFormat) {
                    ForEach(availableFormats) { fmt in
                        Label(fmt.displayName, systemImage: fmt.systemImage)
                            .tag(fmt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            Spacer()
        }
    }

    // MARK: - Output path & name

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Output name").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(".\(targetFormat.fileExtension)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            TextField("Filename", text: $outputName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit { if isValid { performConvert() } }

            HStack {
                Text("Save to").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    chooseOutputDir()
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Choose output folder")
            }
            Text(outputDir)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.head)
        }
    }

    // MARK: - Tool status

    private var toolStatusSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Tool: \(toolInfo)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        HIGDialogButtons(
            confirmTitle: "Convert",
            isConfirmDisabled: !isValid,
            onCancel: onCancel,
            onConfirm: { performConvert() }
        )
    }

    // MARK: - Glass styling

    @ViewBuilder
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    @ViewBuilder
    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    // MARK: - Actions

    private func performConvert() {
        guard isValid else { return }
        log.info("[ConvertMediaDialog] convert \(file.nameStr) → \(targetFormat.rawValue) at \(outputURL.path)")
        onConvert(targetFormat, outputURL)
    }

    private func chooseOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: outputDir)
        if panel.runModal() == .OK, let url = panel.url {
            outputDir = url.path
        }
    }
}
