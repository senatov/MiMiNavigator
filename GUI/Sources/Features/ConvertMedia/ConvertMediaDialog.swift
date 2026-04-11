// ConvertMediaDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Convert Media dialog — glass-panel style matching Network Neighborhood.

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
        static let minWidth: CGFloat = 380
        static let idealWidth: CGFloat = 420
        static let outerCornerRadius: CGFloat = 14
        static let sectionCornerRadius: CGFloat = 12
        static let hPad: CGFloat = 12
        static let compactHPad: CGFloat = 10
    }

    private enum Glass {
        static let borderOpacity: Double = 0.14
        static let sectionTintOpacity: Double = 0.07
        static let headerTintOpacity: Double = 0.09
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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            headerBar
            sourceCard
            targetCard
            outputCard
            toolStatusBar
            buttonBar
        }
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.idealWidth)
        .padding(.top, 10)
        .background(panelBackground)
        .overlay(panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .higAutoFocusTextField()
        .onAppear { isNameFieldFocused = true }
        .onKeyPress(.escape) { onCancel(); return .handled }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Convert Media")
                    .font(.headline)
                Text("Select target format and output location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 8)
        .background(headerBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }

    // MARK: - Source card

    private var sourceCard: some View {
        HStack(spacing: 10) {
            Image(systemName: sourceFormat?.systemImage ?? "doc")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(file.nameStr)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.urlValue.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            if let fmt = sourceFormat {
                Text(fmt.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12)))
            }
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 10)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }

    // MARK: - Target card

    private var targetCard: some View {
        HStack(spacing: 10) {
            Image(systemName: targetFormat.systemImage)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Convert to")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Picker("", selection: $targetFormat) {
                    ForEach(availableFormats) { fmt in
                        Label(fmt.displayName, systemImage: fmt.systemImage).tag(fmt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 10)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }

    // MARK: - Output card

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("OUTPUT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("Filename", text: $outputName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isNameFieldFocused)
                            .onSubmit { if isValid { performConvert() } }
                        Text(".\(targetFormat.fileExtension)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(outputDir)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.head)
                Spacer()
                Button {
                    chooseOutputDir()
                } label: {
                    Text("Choose…")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular.tint(Color.white.opacity(Glass.sectionTintOpacity)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
                )
            }
        }
        .padding(.horizontal, Layout.hPad)
        .padding(.vertical, 10)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHPad)
    }

    // MARK: - Tool status

    private var toolStatusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(toolInfo)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, Layout.hPad + 4)
    }

    // MARK: - Buttons

    private var buttonBar: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.large)
            Button("Convert") { performConvert() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.large)
                .disabled(!isValid)
        }
        .padding(.horizontal, Layout.compactHPad)
        .padding(.bottom, 10)
    }

    // MARK: - Glass styling (identical to NetworkNeighborhoodView)

    @ViewBuilder
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.sectionTintOpacity)))
    }

    @ViewBuilder
    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    @ViewBuilder
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.headerTintOpacity)))
    }

    @ViewBuilder
    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular.tint(Color.white.opacity(Glass.sectionTintOpacity)))
    }

    @ViewBuilder
    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(Glass.borderOpacity), lineWidth: 0.8)
    }

    // MARK: - Actions

    private func performConvert() {
        guard isValid else { return }
        log.info("[ConvertMediaDialog] convert \(file.nameStr) → \(targetFormat.rawValue)")
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
