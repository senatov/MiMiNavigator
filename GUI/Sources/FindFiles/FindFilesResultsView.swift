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
    @State private var cachedSorted: [FindFilesResult] = []
    @State private var lastResultCount: Int = 0
    /// Auto-scroll: tracks whether user has manually selected a row (stops auto-scroll)
    @State private var userHasSelected: Bool = false

    /// Standard font matching FileRow (.system(size: 12))
    static let dialogFont: Font = .system(size: 12)
    private var columnFont: Font { .system(size: 12) }
    /// Monospaced digit variant for numeric columns
    private var monoFont: Font { .system(size: 12).monospacedDigit() }
    /// Active color theme shortcut
    private var theme: ColorTheme { colorStore.activeTheme }

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
        .onChange(of: viewModel.results.count) {
            cachedSorted = viewModel.results.sorted(using: sortOrder)
            lastResultCount = viewModel.results.count
            // Auto-scroll: select last result to keep table scrolled to bottom during search
            if viewModel.searchState == .searching && !userHasSelected,
               let last = cachedSorted.last {
                viewModel.selectedResult = last
            }
        }
        .onChange(of: sortOrder) {
            cachedSorted = viewModel.results.sorted(using: sortOrder)
        }
        .onChange(of: viewModel.searchState) {
            // Reset auto-scroll flag when a new search starts
            if viewModel.searchState == .searching {
                userHasSelected = false
            }
        }
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
                .font(columnFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results List

    private var resultsList: some View {
        Table(cachedSorted, selection: Binding(
            get: { viewModel.selectedResult?.id },
            set: { newID in
                viewModel.selectedResult = viewModel.results.first { $0.id == newID }
                // User clicked a row manually — stop auto-scroll
                if viewModel.searchState == .searching {
                    userHasSelected = true
                }
            }
        ), sortOrder: $sortOrder) {
            // # — sequential row number (not sortable)
            TableColumn("#") { result in
                rowCell(result) {
                    if let idx = cachedSorted.firstIndex(where: { $0.id == result.id }) {
                        Text("\(idx + 1)")
                            .font(monoFont)
                            .foregroundStyle(result.isPasswordProtected ? .red : .secondary)
                    }
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
                rowCell(result) {
                    Text(result.isInsideArchive
                         ? "\u{1F4E6} [\((result.archivePath as NSString?)?.lastPathComponent ?? "archive")] \(result.filePath)"
                         : result.filePath)
                        .font(columnFont)
                        .foregroundStyle(result.isPasswordProtected
                            ? .red
                            : (result.isInsideArchive ? theme.archivePathColor : theme.columnDateColor))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(result.isPasswordProtected
                              ? "🔒 Password protected archive"
                              : (result.isInsideArchive
                                 ? "Inside archive: \(result.archivePath ?? "?")\n\(result.filePath)"
                                 : result.filePath))
                }
            }
            .width(min: 200, ideal: 300)

            // Date — sortable by modifiedDate
            TableColumn("Date Mod.", value: \.sortableDate) { result in
                rowCell(result) {
                    Text(result.modifiedDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                        .font(monoFont)
                        .foregroundStyle(result.isPasswordProtected ? .red : theme.columnDateColor)
                }
            }
            .width(min: 80, ideal: 120)

            // Size — sortable
            TableColumn("Size", value: \.fileSize) { result in
                rowCell(result) {
                    Text(formatSize(result.fileSize))
                        .font(monoFont)
                        .foregroundStyle(result.isPasswordProtected ? .red : theme.columnSizeColor)
                }
            }
            .width(min: 50, ideal: 65)

            // Match context (not sortable)
            TableColumn("Match") { result in
                rowCell(result) {
                    if result.isPasswordProtected {
                        // Password-protected archive — show lock + message
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.red)
                            Text("Password protected")
                                .foregroundStyle(.red)
                        }
                        .font(.system(size: 12, weight: .semibold))
                    } else if let context = result.matchContext, let line = result.lineNumber {
                        Text("L\(line): \(context)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.columnNameColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else if let context = result.matchContext {
                        // Context without line number
                        Text(context)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.columnNameColor)
                            .lineLimit(1)
                    } else {
                        Text("—")
                            .font(columnFont)
                            .foregroundStyle(.quaternary)
                    }
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

    // MARK: - Row Background Helper

    /// Wraps cell content with red background for password-protected archives
    @ViewBuilder
    private func rowCell<Content: View>(_ result: FindFilesResult, @ViewBuilder content: () -> Content) -> some View {
        if result.isPasswordProtected {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.18))
        } else {
            content()
        }
    }

    // MARK: - Name Cell

    private func resultNameCell(_ result: FindFilesResult) -> some View {
        rowCell(result) {
            HStack(spacing: 6) {
                // Password-protected archives get a red lock icon
                if result.isPasswordProtected {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 16)
                } else {
                    Image(systemName: result.isInsideArchive ? "doc.zipper" : fileIcon(for: result))
                        .font(.system(size: 12))
                        .foregroundStyle(result.isInsideArchive
                            ? theme.archivePathColor
                            : theme.columnKindColor)
                        .frame(width: 16)
                }
                Text(result.fileName)
                    .font(.system(size: 12, weight: result.isInsideArchive || result.isPasswordProtected ? .semibold : .regular))
                    .foregroundStyle(result.isPasswordProtected
                        ? .red
                        : (result.isInsideArchive ? theme.archivePathColor : theme.columnNameColor))
                    .lineLimit(1)
            }
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
            Button("Copy as Pathname") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(result.fileURL.path, forType: .string)
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
