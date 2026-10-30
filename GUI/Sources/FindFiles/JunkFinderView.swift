// JunkFinderView.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import SwiftUI

// MARK: - Cleanup Tab
struct JunkFinderView: View {
    @State private var model = JunkFinderModel.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cleanup candidates").font(.headline)
                    Text("Exact duplicates, empty folders, old installers, temporary files, stale PID files and reviewed app leftovers.")
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
                Button("Clear Selection") { model.selectedIDs = [] }
                    .disabled(model.selectedIDs.isEmpty)
                Button("Move \(model.selectedIDs.count) to Trash", systemImage: "trash") { model.trashSelection() }
                    .disabled(model.selectedIDs.isEmpty || model.isTrashing)
            }
            .padding(12)
        }
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

}
