// JunkFinderView.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import SwiftUI

// MARK: - Cleanup Tab
struct JunkFinderView: View {
    @State private var model = JunkFinderModel.shared
    @State private var sortOrder = [KeyPathComparator(\JunkCandidate.name)]
    @State private var highlightedIDs: Set<JunkCandidate.ID> = []
    var appState: AppState?
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()

    private var sortedCandidates: [JunkCandidate] {
        model.candidates.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cleanup candidates").font(.headline)
                    Text("Automatic review of eligible local storage. Scans pause when the app is active or the Mac is busy, and resume from saved progress.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(JunkAIReviewer.statusText)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            HStack(spacing: 8) {
                if model.isScanning { ProgressView().controlSize(.small) }
                Text(model.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(model.candidates.count) candidates").font(.caption.monospacedDigit())
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            Divider()
            if model.candidates.isEmpty {
                ContentUnavailableView("No candidates yet", systemImage: "sparkle.magnifyingglass", description: Text("Scanning starts automatically and waits for spare capacity. System, cloud, backup and development locations are excluded."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                candidatesTable
            }
            Divider()
            HStack(spacing: 10) {
                Text("Review each item. Duplicate groups always retain one copy.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear Selection") { model.selectedIDs = [] }
                    .disabled(model.selectedIDs.isEmpty)
                Button("Move \(model.selectedIDs.count) to Trash", systemImage: "trash") { model.trashSelection() }
                    .disabled(model.selectedIDs.isEmpty || model.isTrashing)
            }
            .padding(12)
        }
    }

    // MARK: - Candidates Table
    private var candidatesTable: some View {
        Table(sortedCandidates, selection: $highlightedIDs, sortOrder: $sortOrder) {
            TableColumn("Review") { candidate in
                Toggle("Review \(candidate.name)", isOn: Binding(
                    get: { model.selectedIDs.contains(candidate.id) },
                    set: { selected in
                        if selected { model.selectedIDs.insert(candidate.id) }
                        else { model.selectedIDs.remove(candidate.id) }
                    }
                ))
                .labelsHidden()
            }
            .width(min: 55, ideal: 65, max: 80)
            TableColumn("Name", value: \.name) { candidate in
                HStack(spacing: 6) {
                    Image(nsImage: FileRowView.getSmartIcon(for: candidate.url))
                        .resizable().interpolation(.high)
                        .frame(width: DesignTokens.Row.iconSize, height: DesignTokens.Row.iconSize)
                    if candidate.kind == .emptyFolder || candidate.kind == .duplicateFolder {
                        Button {
                            navigate(to: candidate.url)
                        } label: {
                            Text(candidate.name).font(.body).foregroundStyle(Color.accentColor)
                                .underline().lineLimit(1).truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState == nil)
                        .accessibilityLabel("Open directory \(candidate.url.path) in the active panel")
                    } else {
                        Text(candidate.name).font(.body).lineLimit(1).truncationMode(.middle)
                    }
                }
                .help(candidate.url.path)
            }
            .width(min: 140, ideal: 220)
            TableColumn("Location", value: \.location) { candidate in
                Button {
                    navigate(to: candidate.url.deletingLastPathComponent())
                } label: {
                    Text(candidate.location)
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                        .underline()
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(appState == nil)
                .help("Open \(candidate.location) in the active panel")
                .accessibilityLabel("Open directory \(candidate.location) in the active panel")
            }
            .width(min: 160, ideal: 320)
            TableColumn("Date Mod.", value: \.sortableDate) { candidate in
                Text(candidate.modified.map { Self.dateFormatter.string(from: $0) } ?? "–")
                    .font(.body.monospacedDigit())
            }
            .width(min: 110, ideal: 150)
            TableColumn("Size", value: \.size) { candidate in
                Text(ByteCountFormatter.string(fromByteCount: candidate.size, countStyle: .file))
                    .font(.body.monospacedDigit())
            }
            .width(min: 65, ideal: 90)
            TableColumn("Kind", value: \.kind.rawValue) { candidate in
                Text(candidate.kind.rawValue).font(.body).lineLimit(1)
            }
            .width(min: 100, ideal: 130)
            TableColumn("Reason") { candidate in
                Text(candidate.reason).font(.body).lineLimit(1).truncationMode(.tail)
                    .help(candidate.reason)
            }
            .width(min: 140, ideal: 300)
        }
        .contextMenu(forSelectionType: JunkCandidate.ID.self) { selection in
            if let id = selection.first, let candidate = model.candidates.first(where: { $0.id == id }) {
                Button("Open Directory in Active Panel") { navigate(to: candidate.url.deletingLastPathComponent()) }
                    .disabled(appState == nil)
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([candidate.url]) }
                if let group = candidate.group {
                    Button("Select Copies Except One") { model.selectGroup(group) }
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .fileTableColumnDividerStyle()
    }

    // MARK: - Navigate to Candidate Directory
    private func navigate(to directoryURL: URL) {
        guard let appState else { return }
        let directory = directoryURL.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        Task { await appState.navigateToDirectory(directory, on: appState.focusedPanel) }
    }
}
