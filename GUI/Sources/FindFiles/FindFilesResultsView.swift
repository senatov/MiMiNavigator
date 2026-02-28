// FindFilesResultsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Results table for Find Files — displays search results with context menu.
//   Columns: #, Name, Path, Date, Size, Match. All sortable except # and Match.

import SwiftUI

// MARK: - Results View

struct FindFilesResultsView: View {
    @Bindable var viewModel: FindFilesViewModel
    var appState: AppState? = nil
    @State private var colorStore = ColorThemeStore.shared

    @State private var sortOrder = [KeyPathComparator(\FindFilesResult.fileName)]

    /// Standard font for the entire Find Files dialog
    static let dialogFont: Font = .system(size: 13, weight: .light, design: .default)

    /// Sorted snapshot — recomputed when results or sortOrder change
    private var sortedResults: [FindFilesResult] {
        viewModel.results.sorted(using: sortOrder)
    }

    // MARK: - Shared date formatter (avoid allocating per-row)

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }()

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
        Table(sortedResults, selection: Binding(
            get: { viewModel.selectedResult?.id },
            set: { newID in
                viewModel.selectedResult = viewModel.results.first { $0.id == newID }
            }
        ), sortOrder: $sortOrder) {
            // # — sequential row number (not sortable)
            TableColumn("#") { result in
                if let idx = sortedResults.firstIndex(where: { $0.id == result.id }) {
                    Text("\(idx + 1)")
                        .font(.system(size: 13, weight: .light).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 30, ideal: 36, max: 50)

            // Name — sortable
            TableColumn("Name", value: \.fileName) { result in
                resultNameCell(result)
            }
            .width(min: 150, ideal: 200)

            // Path — sortable
            TableColumn("Path", value: \.filePath) { result in
                Text(result.isInsideArchive
                     ? "\u{1F4E6} [\((result.archivePath as NSString?)?.lastPathComponent ?? "archive")] \(result.filePath)"
                     : result.filePath)
                    .font(Self.dialogFont)
                    .foregroundStyle(result.isInsideArchive
                        ? colorStore.activeTheme.archivePathColor
                        : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(result.isInsideArchive
                          ? "Inside archive: \(result.archivePath ?? "?")\n\(result.filePath)"
                          : result.filePath)
            }
            .width(min: 200, ideal: 300)

            // Date — sortable by modifiedDate
            TableColumn("Date Mod.", value: \.sortableDate) { result in
                Text(result.modifiedDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                    .font(.system(size: 13, weight: .light).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 120)

            // Size — sortable
            TableColumn("Size", value: \.fileSize) { result in
                Text(formatSize(result.fileSize))
                    .font(.system(size: 13, weight: .light).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 65)

            // Match context (not sortable)
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
            .width(min: 80, ideal: 180)
        }
        .contextMenu(forSelectionType: FindFilesResult.ID.self) { selection in
            resultContextMenu(selection: selection)
        } primaryAction: { selection in
            if let id = selection.first,
               let result = viewModel.results.first(where: { $0.id == id }),
               let state = appState {
                viewModel.goToFile(result: result, appState: state)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Name Cell

    private func resultNameCell(_ result: FindFilesResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: result.isInsideArchive ? "doc.zipper" : fileIcon(for: result))
                .font(.system(size: 13))
                .foregroundStyle(result.isInsideArchive
                    ? colorStore.activeTheme.archivePathColor
                    : .secondary)
                .frame(width: 16)
            Text(result.fileName)
                .font(.system(size: 13, weight: result.isInsideArchive ? .semibold : .light))
                .foregroundStyle(result.isInsideArchive
                    ? colorStore.activeTheme.archivePathColor
                    : .primary)
                .lineLimit(1)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func resultContextMenu(selection: Set<FindFilesResult.ID>) -> some View {
        if let id = selection.first,
           let result = viewModel.results.first(where: { $0.id == id }) {
            Button("Go to File") {
                if let state = appState {
                    viewModel.goToFile(result: result, appState: state)
                }
            }
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
