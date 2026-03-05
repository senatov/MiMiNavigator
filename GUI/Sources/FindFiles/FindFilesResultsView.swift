// FindFilesResultsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Results table for Find Files Ñ displays search results with context menu.
//   Columns: #, Name, Path, Date, Size, Match. All sortable except # and Match.
//   Icons: real NSWorkspace icons via FileRowView.getSmartIcon Ñ same as main panel.

import SwiftUI

// MARK: - Results View

struct FindFilesResultsView: View {
    @Bindable var viewModel: FindFilesViewModel
    var appState: AppState? = nil
    private let colorStore = ColorThemeStore.shared   // @Observable singleton Ñ no @State needed

    @State private var sortOrder    = [KeyPathComparator(\FindFilesResult.fileName)]
    @State private var cachedSorted: [FindFilesResult] = []
    @State private var lastResultCount: Int  = 0
    @State private var userHasSelected: Bool = false  // stops auto-scroll when user clicks

    // MARK: - Fonts (static Ñ same as FileRow)
    private static let rowFont:  Font = .system(size: 12)
    private static let monoFont: Font = .system(size: 12).monospacedDigit()

    // MARK: - Formatters (static Ñ allocated once)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }()

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    private var theme: ColorTheme { colorStore.activeTheme }

    // MARK: - Body

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
            if viewModel.searchState == .searching && !userHasSelected,
               let last = cachedSorted.last {
                viewModel.selectedResult = last
            }
        }
        .onChange(of: sortOrder)              { rebuildSort() }
        .onChange(of: viewModel.searchState)  {
            if viewModel.searchState == .searching { userHasSelected = false }
        }
    }

    // MARK: - Sort

    private func rebuildSort() {
        cachedSorted = viewModel.results.sorted(using: sortOrder)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.searchState == .idle
                  ? "magnifyingglass" : "doc.text.magnifyingglass")
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

    // MARK: - Results Table

    private var resultsList: some View {
        Table(cachedSorted, selection: Binding(
            get: { viewModel.selectedResult?.id },
            set: { newID in
                viewModel.selectedResult = viewModel.results.first { $0.id == newID }
                if let name = viewModel.selectedResult?.fileName {
                    log.debug("[FindFilesResults] selected '\(name)'")
                }
                if viewModel.searchState == .searching { userHasSelected = true }
            }
        ), sortOrder: $sortOrder) {

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

            TableColumn("Name", value: \.fileName) { result in
                resultNameCell(result)
            }
            .width(min: 150, ideal: 200)

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
                              ? "? Password protected archive"
                              : (result.isInsideArchive
                                 ? "Inside archive: \(result.archivePath ?? "?")\n\(result.filePath)"
                                 : result.filePath))
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("Date Mod.", value: \.sortableDate) { result in
                rowCell(result) {
                    Text(result.modifiedDate.map { Self.dateFormatter.string(from: $0) } ?? "Ñ")
                        .font(Self.monoFont)
                        .foregroundStyle(result.isPasswordProtected ? .red : theme.columnDateColor)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Size", value: \.fileSize) { result in
                rowCell(result) {
                    Text(Self.formatSize(result.fileSize))
                        .font(Self.monoFont)
                        .foregroundStyle(result.isPasswordProtected ? .red : theme.columnSizeColor)
                }
            }
            .width(min: 50, ideal: 65)

            TableColumn("Match") { result in
                rowCell(result) {
                    if result.isPasswordProtected {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill").foregroundStyle(.red)
                            Text("Password protected").foregroundStyle(.red)
                        }
                        .font(.system(size: 12, weight: .semibold))
                    } else if let context = result.matchContext, let line = result.lineNumber {
                        Text("L\(line): \(context)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.columnNameColor)
                            .lineLimit(1).truncationMode(.tail)
                    } else if let context = result.matchContext {
                        Text(context)
                            .font(Self.rowFont)
                            .foregroundStyle(theme.columnNameColor)
                            .lineLimit(1)
                    } else {
                        Text("Ñ").font(Self.rowFont).foregroundStyle(.quaternary)
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

    @ViewBuilder
    private func rowCell<Content: View>(
        _ result: FindFilesResult,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if result.isPasswordProtected {
            content().background(Color.red.opacity(0.18))
        } else {
            content()
        }
    }

    // MARK: - Name Cell
    // Real NSWorkspace icons via FileRowView.getSmartIcon Ñ same chain as main panel

    private func resultNameCell(_ result: FindFilesResult) -> some View {
        rowCell(result) {
            HStack(spacing: 6) {
                Image(nsImage: FileRowView.getSmartIcon(for: result.fileURL))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
                    .opacity(result.isInsideArchive ? 0.75 : 1.0)
                Text(result.fileName)
                    .font(Self.rowFont.weight(
                        result.isInsideArchive || result.isPasswordProtected ? .semibold : .regular))
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
                if let state = appState { viewModel.goToFile(result: result, appState: state) }
            }
            Button("Open") {}.disabled(true)
            Button("Reveal in Finder") { viewModel.revealInFinder(result: result) }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.filePath, forType: .string)
            }
            Button("Copy as Pathname") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.fileURL.path, forType: .string)
            }
        }
        Divider()
        Button("Copy All Paths") { viewModel.copyResultPaths() }
            .disabled(viewModel.results.isEmpty)
        Button("Export ResultsÉ") { viewModel.exportResults() }
            .disabled(viewModel.results.isEmpty)
    }

    // MARK: - Helpers

    private static func formatSize(_ bytes: Int64) -> String {
        bytes == 0 ? "Ñ" : sizeFormatter.string(fromByteCount: bytes)
    }
}
