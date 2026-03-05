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
    private let colorStore = ColorThemeStore.shared

    @State private var sortOrder = [KeyPathComparator(\FindFilesResult.fileName)]
    @State private var cachedSorted: [FindFilesResult] = []
    @State private var lastResultCount: Int = 0
    /// Auto-scroll: tracks whether user has manually selected a row (stops auto-scroll)
    @State private var userHasSelected: Bool = false

    // Fonts matching FileRow
    private static let rowFont: Font = .system(size: 12)


    private static let Self.monoFont: Font = .system(size: 12).monospacedDigit()
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
            rebuildSort()
            lastResultCount = viewModel.results.count
            // Auto-scroll: select last result to keep table scrolled to bottom during search
            if viewModel.searchState == .searching && !userHasSelected,
               let last = cachedSorted.last {
                viewModel.selectedResult = last
            }
        }
        .onChange(of: sortOrder) { rebuildSort() }
        .onChange(of: viewModel.searchState) {
            // Reset auto-scroll flag when a new search starts
            if viewModel.searchState == .searching {
                userHasSelected = false
            }
        }
    }

    // MARK: - Sort
    private func rebuildSort() {
        cachedSorted = viewModel.results.sorted(using: sortOrder)
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
                .font(Self.rowFont)
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
                if let name = viewModel.selectedResult?.fileName {
                    log.debug("[FindFilesResults] selected '\(name)'")
                }
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
                            .font(Self.monoFont)
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
                        .font(Self.rowFont)
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
                        .font(Self.monoFont)
                        .foregroundStyle(result.isPasswordProtected ? .red : theme.columnDateColor)
                }
            }
            .width(min: 80, ideal: 120)

            // Size — sortable
            TableColumn("Size", value: \.fileSize) { result in
                rowCell(result) {
                    Text(Self.formatSize(result.fileSize))
                        .font(Self.monoFont)
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
                            Image(nsImage: FileRowView.getSmartIcon(for: result.fileURL))
                        .resizable().interpolation(.high)
                        .frame(width: 16, height: 16)
                } else {
                    Image(nsImage: FileRowView.getSmartIcon(for: result.fileURL))
                        .resizable().interpolation(.high)
                        .frame(width: 16, height: 16)
                        .opacity(result.isInsideArchive ? 0.7 : 1.0)
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

    // fileIcon() removed

    private static let sizeFormatter: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()    private static func formatSize(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
