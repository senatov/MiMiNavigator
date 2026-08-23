// FindFilesResultsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Results table for Find Files - displays search results with context menu.
//   Columns: #, Name, Path, Date, Size, Match. All sortable except # and Match.
//   Icons: real NSWorkspace icons via FileRowView.getSmartIcon - same as main panel.

import SwiftUI
import FindFilesKit

// MARK: - Results View

struct FindFilesResultsView: View {
    @Bindable var viewModel: FindFilesViewModel
    var appState: AppState?
    private let colorStore = ColorThemeStore.shared // @Observable singleton - no @State needed

    @State private var sortOrder = [KeyPathComparator(\FindFilesResult.fileName)]
    @State private var cachedSorted: [FindFilesResult] = []
    @State private var lastResultCount: Int = 0
    @State private var userHasSelected: Bool = false // stops auto-scroll when user clicks
    @State private var sortTask: Task<Void, Never>?
    @State private var columnCustomization: TableColumnCustomization<FindFilesResult>
    private static let columnsKey = "findFiles.columns.v1"

    init(viewModel: FindFilesViewModel, appState: AppState? = nil) {
        self.viewModel = viewModel
        self.appState = appState
        let stored = MiMiDefaults.shared.data(forKey: Self.columnsKey)
        let decoded = stored.flatMap {
            try? JSONDecoder().decode(TableColumnCustomization<FindFilesResult>.self, from: $0)
        }
        _columnCustomization = State(initialValue: decoded ?? TableColumnCustomization())
    }

    // MARK: - Fonts (static - same as FileRow)

    private static let rowFont: Font = .system(size: 12)
    private static let monoFont: Font = .system(size: 12).monospacedDigit()

    // MARK: - Formatters (static - allocated once)

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

    private var theme: ColorTheme {
        colorStore.activeTheme
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.results.isEmpty && viewModel.searchState != .searching {
                emptyState
            } else {
                resultsToolbar
                resultsList
            }
        }
        .frame(minHeight: 150, idealHeight: 250)
        .onChange(of: viewModel.results.count) {
            scheduleSort()
            lastResultCount = viewModel.results.count
            if viewModel.searchState == .searching && !userHasSelected,
               let last = cachedSorted.last
            {
                viewModel.selectedResult = last
            }
        }
        .onChange(of: sortOrder) { rebuildSort() }
        .onChange(of: viewModel.selectedResultIDs) {
            viewModel.selectedResult = viewModel.results.first {
                viewModel.selectedResultIDs.contains($0.id)
            }
            if viewModel.searchState == .searching {
                userHasSelected = !viewModel.selectedResultIDs.isEmpty
            }
        }
        .onChange(of: columnCustomization) {
            guard let data = try? JSONEncoder().encode(columnCustomization) else { return }
            MiMiDefaults.shared.set(data, forKey: Self.columnsKey)
        }
        .onChange(of: viewModel.searchState) {
            if viewModel.searchState == .searching { userHasSelected = false }
            if viewModel.searchState != .searching {
                sortTask?.cancel()
                sortTask = nil
                rebuildSort()
            }
        }
        .onDisappear { sortTask?.cancel() }
    }

    // MARK: - Sort

    private func rebuildSort() {
        cachedSorted = viewModel.results.sorted(using: sortOrder)
    }

    private func scheduleSort() {
        if cachedSorted.isEmpty {
            rebuildSort()
            return
        }
        guard sortTask == nil else { return }
        sortTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else {
                sortTask = nil
                return
            }
            rebuildSort()
            sortTask = nil
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(
                systemName: viewModel.searchState == .idle
                    ? "magnifyingglass" : "doc.text.magnifyingglass"
            )
            .font(.system(size: 32))
            .foregroundStyle(.tertiary)
            Text(
                viewModel.searchState == .idle
                    ? "Enter search criteria and press Search"
                    : "No files found"
            )
            .font(Self.rowFont)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results Table

    private var resultsToolbar: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.selectedResultIDs.count) selected")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                columnToggle("Number", id: "number")
                columnToggle("Name", id: "name")
                columnToggle("Location", id: "path")
                columnToggle("Date Modified", id: "date")
                columnToggle("Size", id: "size")
                columnToggle("Match", id: "match")
                Divider()
                Button("Reset Columns") {
                    columnCustomization = TableColumnCustomization()
                }
            } label: {
                Label("Columns", systemImage: "rectangle.split.3x1")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var resultsList: some View {
        Table(
            cachedSorted,
            selection: $viewModel.selectedResultIDs,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
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
            .customizationID("number")

            TableColumn("Name", value: \.fileName) { result in
                resultNameCell(result)
            }
            .width(min: 220, ideal: 420)
            .customizationID("name")

            TableColumn("Location", value: \.filePath) { result in
                rowCell(result) {
                    Text(displayedLocation(for: result))
                    .font(Self.rowFont)
                    .foregroundStyle(
                        result.isPasswordProtected
                            ? .red
                            : (result.isInsideArchive ? theme.archivePathColor : theme.columnDateColor)
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(
                        result.isPasswordProtected
                            ? "? Password protected archive"
                            : (result.isInsideArchive
                                ? "Inside archive: \(result.archivePath ?? "?")\n\(result.filePath)"
                                : result.filePath)
                    )
                }
            }
            .width(min: 160, ideal: 260, max: 320)
            .customizationID("path")

            TableColumn("Date Mod.", value: \.sortableDate) { result in
                rowCell(result) {
                    Text(result.modifiedDate.map { Self.dateFormatter.string(from: $0) } ?? "-")
                        .font(Self.monoFont)
                        .foregroundStyle(result.isPasswordProtected ? .red : theme.columnDateColor)
                }
            }
            .width(min: 130, ideal: 150, max: 170)
            .customizationID("date")

            TableColumn("Size", value: \.fileSize) { result in
                rowCell(result) {
                    Text(Self.formatSize(result.fileSize))
                        .font(Self.monoFont)
                        .foregroundStyle(result.isPasswordProtected ? .red : theme.columnSizeColor)
                }
            }
            .width(min: 30, ideal: 75)
            .customizationID("size")

            TableColumn("Match") { result in
                rowCell(result) {
                    if result.isPasswordProtected {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill").foregroundStyle(.red)
                            Text("Password protected").foregroundStyle(.red)
                        }
                        .font(.system(size: 12, weight: .light))
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
                        Text("-").font(Self.rowFont).foregroundStyle(.quaternary)
                    }
                }
            }
            .width(min: 50, ideal: 220)
            .customizationID("match")
        }
        .contextMenu(forSelectionType: FindFilesResult.ID.self) { selection in
            resultContextMenu(selection: selection)
        } primaryAction: { selection in
            if let id = selection.first,
               let result = viewModel.results.first(where: { $0.id == id }),
               let state = appState
            {
                viewModel.goToFile(result: result, appState: state)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .fileTableColumnDividerStyle()
        .background(
            FindFilesResultsTableStyle(
                selectionVersion: viewModel.selectedResultIDs.hashValue,
                themeVersion: colorStore.themeVersion
            )
        )
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

    // Real NSWorkspace icons via FileRowView.getSmartIcon - same chain as main panel

    private func resultNameCell(_ result: FindFilesResult) -> some View {
        rowCell(result) {
            HStack(spacing: 6) {
                Image(nsImage: FileRowView.getSmartIcon(for: result.fileURL))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
                    .opacity(result.isInsideArchive ? 0.75 : 1.0)
                Text(result.fileName)
                    .font(
                        Self.rowFont.weight(
                            result.isInsideArchive || result.isPasswordProtected ? .light : .regular
                        )
                    )
                    .foregroundStyle(
                        result.isPasswordProtected
                            ? .red
                            : (result.isInsideArchive ? theme.archivePathColor : theme.columnNameColor)
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(result.fileName)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func resultContextMenu(selection: Set<FindFilesResult.ID>) -> some View {
        let selected = viewModel.results.filter { selection.contains($0.id) }
        let actionable = selected.filter { !$0.isInsideArchive && !$0.isPasswordProtected }
        if selected.count == 1, let result = selected.first {
            Button("Go to File") {
                if let state = appState { viewModel.goToFile(result: result, appState: state) }
            }
            .disabled(appState == nil)
            Button("Reveal in Finder") { viewModel.revealInFinder(result: result) }
        }
        Button(selected.count == 1 ? "Open" : "Open \(selected.count) Items") {
            viewModel.openResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Divider()
        Button(selected.count == 1 ? "Copy to Folder…" : "Copy \(selected.count) Items to Folder…") {
            viewModel.copyResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Button(selected.count == 1 ? "Move to Folder…" : "Move \(selected.count) Items to Folder…") {
            viewModel.moveResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Button(selected.count == 1 ? "Move to Trash" : "Move \(selected.count) Items to Trash", role: .destructive) {
            viewModel.trashResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Divider()
        Button(selected.count == 1 ? "Copy Path" : "Copy \(selected.count) Paths") {
            viewModel.copyPaths(for: selected)
        }
        Divider()
        Button("Select All") { viewModel.selectAllResults() }
        Button("Copy All Paths") { viewModel.copyResultPaths() }
            .disabled(viewModel.results.isEmpty)
        Button("Export Results…") { viewModel.exportResults() }
            .disabled(viewModel.results.isEmpty)
    }

    // MARK: - Column Customization

    private func columnToggle(_ title: String, id: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { columnCustomization[visibility: id] != .hidden },
            set: { columnCustomization[visibility: id] = $0 ? .visible : .hidden }
        ))
    }

    // MARK: - Helpers

    private func displayedLocation(for result: FindFilesResult) -> String {
        let parentPath = (result.filePath as NSString).deletingLastPathComponent
        guard result.isInsideArchive else { return parentPath }
        let archiveName = (result.archivePath as NSString?)?.lastPathComponent ?? "archive"
        return "\u{1F4E6} [\(archiveName)] \(parentPath)"
    }

    private static func formatSize(_ bytes: Int64) -> String {
        bytes == 0 ? "0 bytes" : sizeFormatter.string(fromByteCount: bytes)
    }
}
