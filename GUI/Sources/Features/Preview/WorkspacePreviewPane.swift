// WorkspacePreviewPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.08.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Native trailing Preview inspector for the active file panel.

import AppKit
import FileModelKit
@preconcurrency import Quartz
import SwiftUI

// MARK: - Workspace Preview Pane
struct WorkspacePreviewPane: View {
    @Environment(AppState.self) private var appState
    @State private var metadata: PreviewFileMetadata?
    @State private var metadataTask: Task<Void, Never>?
    @State private var modeStore = PreviewDisplayModeStore.shared
    @State private var textSearch = ""
    @State private var textSearchStep = 0
    let sourceSide: FavPanelSide
    let previewSide: FavPanelSide
    let close: () -> Void
    let swapSide: () -> Void
    private var selectedFile: CustomFile? {
        appState[panel: sourceSide].selectedFile
    }
    private var previewURL: URL? {
        guard let selectedFile, !selectedFile.isParentEntry else { return nil }
        return selectedFile.urlValue
    }
    private var isTextPreview: Bool {
        guard let previewURL else { return false }
        return modeStore.mode(for: previewURL) == .text
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let url = previewURL {
                previewContent(url: url)
            } else {
                emptyState
            }
        }
        .background(.regularMaterial)
        .onAppear { refreshMetadata(for: previewURL) }
        .onChange(of: previewURL) { _, newURL in
            textSearch = ""
            textSearchStep = 0
            refreshMetadata(for: newURL)
        }
        .onDisappear {
            metadataTask?.cancel()
            metadataTask = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview pane")
        .contextMenu {
            Button(previewSide == .left ? "Move Preview to Right" : "Move Preview to Left", action: swapSide)
            if let url = previewURL {
                Menu("Display as") {
                    ForEach(PreviewDisplayMode.allCases) { mode in
                        Button {
                            modeStore.set(mode, for: url)
                        } label: {
                            Label(mode.title, systemImage: mode.symbol)
                        }
                    }
                    Divider()
                    Button("Use Automatic Setting") {
                        modeStore.removeRule(forExtension: modeStore.extensionKey(for: url))
                    }
                }
            }
            Divider()
            Button("Hide Preview", action: close)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
                .foregroundStyle(.secondary)
            Text("Preview")
                .font(.system(size: 13, weight: .semibold))
            Text(sourceSide == .left ? "Left source" : "Right source")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer(minLength: 0)
            if isTextPreview {
                textSearchField
            }
            Button(action: swapSide) {
                Image(systemName: "rectangle.2.swap")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help(previewSide == .left ? "Move Preview to Right" : "Move Preview to Left")
            Button(action: close) {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help("Hide Preview (⇧⌘P)")
            .accessibilityLabel("Hide Preview")
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
    }

    // MARK: - Text Search
    private var textSearchField: some View {
        HStack(spacing: 3) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search", text: $textSearch)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit { textSearchStep += 1 }
            if !textSearch.isEmpty {
                Button { textSearchStep -= 1 } label: {
                    Image(systemName: "chevron.up")
                }
                .help("Previous Match")
                Button { textSearchStep += 1 } label: {
                    Image(systemName: "chevron.down")
                }
                .help("Next Match")
                Button {
                    textSearch = ""
                    textSearchStep = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .help("Clear Search")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 7)
        .frame(width: 190, height: 24)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.65)
        }
    }

    // MARK: - Preview Content
    private func previewContent(url: URL) -> some View {
        VStack(spacing: 0) {
            previewRenderer(url: url)
            Divider()
            metadataSection(url: url)
        }
    }

    @ViewBuilder
    private func previewRenderer(url: URL) -> some View {
        switch modeStore.mode(for: url) {
        case .quickLook:
            QuickLookPreviewView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
        case .text:
            TextFilePreview(url: url, searchText: textSearch, searchStep: textSearchStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .binary:
            BinaryFilePreview(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case nil:
            unknownTypeChooser(url: url)
        }
    }

    private func unknownTypeChooser(url: URL) -> some View {
        ContentUnavailableView {
            Label("Choose Preview Mode", systemImage: "questionmark.square.dashed")
        } description: {
            Text("How should .\(modeStore.extensionKey(for: url)) files be shown?")
        } actions: {
            HStack(spacing: 10) {
                ForEach(PreviewDisplayMode.allCases) { mode in
                    Button {
                        modeStore.set(mode, for: url)
                    } label: {
                        Label(mode.title, systemImage: mode.symbol)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing Selected", systemImage: "doc.richtext")
        } description: {
            Text("Select an item in the active panel to preview it.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Metadata Section
    private func metadataSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(url.lastPathComponent)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            if let metadata {
                LabeledContent("Kind", value: metadata.kind)
                if let size = metadata.size {
                    LabeledContent("Size", value: size)
                }
                if let modified = metadata.modified {
                    LabeledContent("Modified", value: modified)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Text(url.deletingLastPathComponent().path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(url.path)
                .textSelection(.enabled)
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    // MARK: - Metadata Refresh
    private func refreshMetadata(for url: URL?) {
        metadataTask?.cancel()
        metadata = nil
        guard let url else { return }
        metadataTask = Task {
            let resolved = await Task.detached(priority: .utility) {
                PreviewFileMetadata(url: url)
            }.value
            guard !Task.isCancelled, previewURL == url else { return }
            metadata = resolved
        }
    }
}

// MARK: - Quick Look Preview View
private struct QuickLookPreviewView: NSViewRepresentable {
    let url: URL

    // MARK: - Make View
    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        view.shouldCloseWithWindow = false
        return view
    }

    // MARK: - Update View
    func updateNSView(_ view: QLPreviewView, context: Context) {
        view.previewItem = QuickLookItem(url: url)
        view.refreshPreviewItem()
    }
}

// MARK: - Preview File Metadata
private struct PreviewFileMetadata: Sendable {
    let kind: String
    let size: String?
    let modified: String?

    // MARK: - Init
    init(url: URL) {
        let keys: Set<URLResourceKey> = [.localizedTypeDescriptionKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        let values = try? url.resourceValues(forKeys: keys)
        var isDirectory = values?.isDirectory == true
        if values?.isDirectory == nil {
            var directoryFlag: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &directoryFlag) {
                isDirectory = directoryFlag.boolValue
            }
        }
        kind = values?.localizedTypeDescription ?? (isDirectory ? "Folder" : "File")
        if isDirectory {
            size = nil
        } else if let byteCount = values?.fileSize {
            size = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
        } else {
            size = nil
        }
        if let date = values?.contentModificationDate {
            modified = date.formatted(date: .abbreviated, time: .shortened)
        } else {
            modified = nil
        }
    }
}
