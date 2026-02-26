// FindFilesResultsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Results table for Find Files — displays search results with context menu

import SwiftUI

// MARK: - Results View
struct FindFilesResultsView: View {
    @Bindable var viewModel: FindFilesViewModel
    var appState: AppState? = nil

    @State private var sortOrder = [KeyPathComparator(\FindFilesResult.fileName)]
    @State private var hoveredResult: FindFilesResult?

    /// Standard font for the entire Find Files dialog
    static let dialogFont: Font = .system(size: 13, weight: .light, design: .default)

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.results.isEmpty && viewModel.searchState != .searching {
                emptyState
            } else {
                resultsList
            }
        }
        .frame(minHeight: 150, idealHeight: 250)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.searchState == .idle ? "magnifyingglass" : "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(viewModel.searchState == .idle
                 ? "Enter search criteria and press Search"
                 : "No files found")
                .font(Self.dialogFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results List
    private var resultsList: some View {
        Table(viewModel.results, selection: Binding(
            get: { viewModel.selectedResult?.id },
            set: { newID in
                viewModel.selectedResult = viewModel.results.first { $0.id == newID }
            }
        ), sortOrder: $sortOrder) {
            // Row number column
            TableColumn("#") { result in
                if let idx = viewModel.results.firstIndex(where: { $0.id == result.id }) {
                    Text("\(idx + 1)")
                        .font(.system(size: 13, weight: .light).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 30, ideal: 36, max: 50)
            TableColumn("Name", value: \.fileName) { result in
                resultNameCell(result)
            }
            .width(min: 150, ideal: 200)

            TableColumn("Path") { result in
                Text(result.isInsideArchive
                     ? "\u{1F4E6} [\((result.archivePath as NSString?)?.lastPathComponent ?? "archive")] \(result.filePath)"
                     : result.filePath)
                    .font(Self.dialogFont)
                    .foregroundStyle(result.isInsideArchive
                        ? Color(#colorLiteral(red: 0.1, green: 0.1, blue: 0.55, alpha: 1))
                        : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(result.isInsideArchive
                          ? "Inside archive: \(result.archivePath ?? "?")\n\(result.filePath)"
                          : result.filePath)
            }
            .width(min: 200, ideal: 300)

            TableColumn("Match") { result in
                if let context = result.matchContext, let line = result.lineNumber {
                    Text("L\(line): \(context)")
                        .font(.system(size: 13, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("—")
                        .font(Self.dialogFont)
                        .foregroundStyle(.quaternary)
                }
            }
            .width(min: 100, ideal: 200)

            TableColumn("Size") { result in
                Text(formatSize(result.fileSize))
                    .font(.system(size: 13, weight: .light).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(50)
        }
        .contextMenu(forSelectionType: FindFilesResult.ID.self) { selection in
            resultContextMenu(selection: selection)
        } primaryAction: { selection in
            // Double-click: go to file
            if let id = selection.first,
               let result = viewModel.results.first(where: { $0.id == id }),
               let state = appState {
                viewModel.goToFile(result: result, appState: state)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Name Cell (archive-aware coloring)
    /// Archive results display in dark navy blue to distinguish them from normal results
    private func resultNameCell(_ result: FindFilesResult) -> some View {
        HStack(spacing: 6) {
            // Icon
            Image(systemName: result.isInsideArchive ? "doc.zipper" : fileIcon(for: result))
                .font(.system(size: 13))
                .foregroundStyle(result.isInsideArchive
                    ? Color(#colorLiteral(red: 0.1, green: 0.1, blue: 0.55, alpha: 1))
                    : .secondary)
                .frame(width: 16)

            Text(result.fileName)
                .font(.system(size: 13, weight: result.isInsideArchive ? .semibold : .light))
                .foregroundStyle(result.isInsideArchive
                    ? Color(#colorLiteral(red: 0.1, green: 0.1, blue: 0.55, alpha: 1))
                    : .primary)
                .lineLimit(1)
        }
    }

    // MARK: - Context Menu
    @ViewBuilder
    private func resultContextMenu(selection: Set<FindFilesResult.ID>) -> some View {
        if let id = selection.first,
           let result = viewModel.results.first(where: { $0.id == id }) {

            // Go to File: navigate panel to the file; if inside archive — open archive, then navigate.
            // The Find Files dialog stays open in both cases.
            Button("Go to File") {
                if let state = appState {
                    viewModel.goToFile(result: result, appState: state)
                }
            }

            // Open: not yet implemented — disabled
            Button("Open") {}
                .disabled(true)

            Button("Reveal in Finder") {
                viewModel.revealInFinder(result: result)
            }

            Divider()

            Button("Copy Path") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(result.filePath, forType: .string)
            }
        }

        Divider()

        Button("Copy All Paths") {
            viewModel.copyResultPaths()
        }
        .disabled(viewModel.results.isEmpty)

        // Export: saves list with query header (name pattern, text, directory, date)
        Button("Export Results…") {
            viewModel.exportResults()
        }
        .disabled(viewModel.results.isEmpty)
    }

    // MARK: - Helpers

    private func fileIcon(for result: FindFilesResult) -> String {
        let ext = result.fileURL.pathExtension.lowercased()
        switch ext {
        case "swift", "java", "py", "js", "ts", "c", "cpp", "h", "rs", "go":
            return "chevron.left.forwardslash.chevron.right"
        case "txt", "md", "rtf", "log":
            return "doc.text"
        case "pdf":
            return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "heic":
            return "photo"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "zip", "7z", "tar", "gz", "bz2", "rar":
            return "doc.zipper"
        case "app", "dmg", "pkg":
            return "app.badge.checkmark"
        default:
            return "doc"
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
