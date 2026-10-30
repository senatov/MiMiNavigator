// JunkFinderView.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import SwiftUI

// MARK: - Cleanup Tab
struct JunkFinderView: View {
    let searchDirectory: String
    @State private var model = JunkFinderModel.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cleanup candidates").font(.headline)
                    Text("Exact duplicates, empty folders, old installers and temporary files in the selected folder.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Scan Again", systemImage: "arrow.clockwise") { model.start(path: searchDirectory) }
                    .disabled(model.isScanning)
                if model.isScanning {
                    Button("Stop", systemImage: "stop.fill") { model.stop() }
                }
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
                ContentUnavailableView("No candidates yet", systemImage: "sparkle.magnifyingglass", description: Text("The scan waits until the app is in the background and the Mac has spare capacity."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack(spacing: 10) {
                Text("Review each item. Duplicate groups always retain one copy.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Select All Except One per Group") { selectSafeCandidates() }
                    .disabled(model.candidates.isEmpty)
                Button("Clear Selection") { model.selectedIDs = [] }
                    .disabled(model.selectedIDs.isEmpty)
                Button("Move \(model.selectedIDs.count) to Trash", systemImage: "trash") { model.trashSelection() }
                    .disabled(model.selectedIDs.isEmpty || !model.scanSucceeded)
            }
            .padding(12)
        }
        .onAppear { model.start(path: model.preferredScope ?? searchDirectory, automatic: true) }
    }

    // MARK: - Candidate Row
    private func candidateRow(_ candidate: JunkCandidate) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { model.selectedIDs.contains(candidate.id) },
                set: { selected in
                    if selected { model.selectedIDs.insert(candidate.id) }
                    else { model.selectedIDs.remove(candidate.id) }
                }
            ))
            .labelsHidden()
            Image(systemName: candidate.kind == .emptyFolder ? "folder" : "doc")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.url.lastPathComponent).lineLimit(1)
                Text(candidate.url.deletingLastPathComponent().path)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Text(candidate.reason).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(candidate.kind.rawValue).font(.caption).foregroundStyle(.secondary)
            Text(ByteCountFormatter.string(fromByteCount: candidate.size, countStyle: .file))
                .font(.caption.monospacedDigit()).frame(minWidth: 65, alignment: .trailing)
            if let group = candidate.group {
                Button("Select copies") { model.selectGroup(group) }
                    .font(.caption).help("Select every file in this exact duplicate group except one")
            }
            Button("Reveal", systemImage: "arrow.up.right.square") {
                NSWorkspace.shared.activateFileViewerSelecting([candidate.url])
            }
            .labelStyle(.iconOnly)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Safe Group Selection
    private func selectSafeCandidates() {
        let duplicateFolders = model.candidates.filter { $0.kind == .duplicateFolder }.map(\.id)
        model.selectedIDs = Set(model.candidates.filter { candidate in
            candidate.group == nil && !duplicateFolders.contains { candidate.id.hasPrefix($0 + "/") }
        }.map(\.id))
        let groups = Set(model.candidates.compactMap(\.group))
        for group in groups { model.selectGroup(group) }
    }
}
