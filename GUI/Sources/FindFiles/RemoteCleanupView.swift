// RemoteCleanupView.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reviews cleanup candidates within a connected remote directory.

import FileModelKit
import Foundation
import SwiftUI

// MARK: - Remote Cleanup Candidate
struct RemoteCleanupCandidate: Identifiable, Sendable {
    let url: URL
    let item: RemoteFileItem
    let category: String
    let reason: String
    var id: String { url.absoluteString }
}

// MARK: - Remote Cleanup Scanner
actor RemoteCleanupScanner {
    func scan(root: URL, provider: any RemoteFileProvider,
              onProgress: @Sendable (Int) async -> Void) async throws -> [RemoteCleanupCandidate] {
        let rootPath = root.path.isEmpty ? "/" : root.path
        var directories = [rootPath]
        var candidates: [RemoteCleanupCandidate] = []
        var visited = 0
        while let directory = directories.popLast() {
            try Task.checkCancellation()
            let entries: [RemoteFileItem]
            do {
                entries = try await provider.listDirectory(directory)
            } catch {
                if error is CancellationError { throw error }
                if directory == rootPath { throw error }
                log.warning("[RemoteCleanup] directory skipped '\(directory)': \(error.localizedDescription)")
                continue
            }
            for item in entries {
                try Task.checkCancellation()
                guard RemoteSearchPathScope.contains(item.path, root: rootPath) else { continue }
                visited += 1
                if item.isDirectory && !item.name.hasPrefix(".") { directories.append(item.path) }
                let category: String
                let reason: String
                let age = item.modified.map { Date().timeIntervalSince($0) / 86_400 }
                let ext = item.fileExtension.lowercased()
                var isEmptyFolder = false
                if item.isDirectory { isEmptyFolder = await entriesForEmptyCheck(item, provider: provider) }
                if isEmptyFolder {
                    category = "Empty folder"
                    reason = "No items in this remote folder"
                } else if !item.isDirectory && ["dmg", "pkg", "xip"].contains(ext) && (age ?? 0) >= 90 {
                    category = "Old installer"
                    reason = "Installer older than 90 days"
                } else if !item.isDirectory && ["tmp", "temp", "part"].contains(ext) && (age ?? 0) >= 30 {
                    category = "Temporary file"
                    reason = "Temporary file older than 30 days"
                } else if !item.isDirectory && item.path.contains("/Library/Caches/")
                            && item.size >= 10_000_000 && (age ?? 0) >= 90 {
                    category = "Application cache"
                    reason = "Cache file over 10 MB and older than 90 days"
                } else {
                    continue
                }
                var components = URLComponents(url: root, resolvingAgainstBaseURL: false)!
                components.path = item.path
                candidates.append(RemoteCleanupCandidate(url: components.url!, item: item,
                    category: category, reason: reason))
            }
            await onProgress(visited)
        }
        return candidates
    }

    private func entriesForEmptyCheck(_ item: RemoteFileItem, provider: any RemoteFileProvider) async -> Bool {
        guard item.isDirectory else { return false }
        return (try? await provider.listDirectory(item.path))?.isEmpty ?? false
    }
}

// MARK: - Remote Cleanup Model
@MainActor
@Observable
private final class RemoteCleanupModel {
    private(set) var candidates: [RemoteCleanupCandidate] = []
    private(set) var isScanning = false
    private(set) var isDeleting = false
    private(set) var visited = 0
    private(set) var status = "Ready to scan the selected remote directory."
    var selectedIDs = Set<String>()
    private var task: Task<Void, Never>?
    func start(path: String) {
        guard !isScanning else { return }
        guard let root = URL(string: path), let connection = RemoteConnectionManager.shared.connection(for: root) else {
            status = "Connect to this server before scanning."
            return
        }
        candidates = []
        selectedIDs = []
        visited = 0
        isScanning = true
        status = "Scanning remote directory…"
        let scanner = RemoteCleanupScanner()
        task = Task { [weak self] in
            do {
                let found = try await scanner.scan(root: root, provider: connection.provider) { [weak self] count in
                    await MainActor.run { self?.visited = count }
                }
                guard let self, !Task.isCancelled else { return }
                self.candidates = found
                self.status = "Scan complete: \(found.count) candidates in \(self.visited) items. Review before deleting."
                self.isScanning = false
            } catch is CancellationError {
                self?.isScanning = false
                self?.status = "Scan stopped."
            } catch {
                self?.isScanning = false
                self?.status = "Remote scan failed: \(error.localizedDescription)"
                log.error("[RemoteCleanup] \(error.localizedDescription)")
            }
        }
    }
    func stop() {
        task?.cancel()
        task = nil
        isScanning = false
        status = "Scan stopped."
    }
    func deleteSelected() {
        let selected = candidates.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        isDeleting = true
        Task { [weak self] in
            guard let self else { return }
            var removed = Set<String>()
            for candidate in selected {
                do {
                    let connection = try RemoteConnectionManager.shared.requireConnection(for: candidate.url)
                    try await connection.provider.deleteItem(at: candidate.item.path, recursive: candidate.item.isDirectory)
                    removed.insert(candidate.id)
                } catch {
                    self.status = "Delete failed for \(candidate.item.name): \(error.localizedDescription)"
                    log.error("[RemoteCleanup] delete failed: \(error.localizedDescription)")
                    break
                }
            }
            self.candidates.removeAll { removed.contains($0.id) }
            self.selectedIDs.subtract(removed)
            self.isDeleting = false
            if removed.count == selected.count { self.status = "Deleted \(removed.count) remote items." }
        }
    }
}

// MARK: - Remote Cleanup View
struct RemoteCleanupView: View {
    let searchDirectory: String
    @State private var model = RemoteCleanupModel()
    @State private var showDeleteConfirmation = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remote cleanup").font(.headline)
                    Text(searchDirectory).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                    Text("Finds empty folders, old installers, temporary files, and old large cache files in this directory. Deletion is permanent on the server.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isScanning { ProgressView().controlSize(.small) }
                Button(model.isScanning ? "Stop" : "Scan again") {
                    if model.isScanning { model.stop() } else { model.start(path: searchDirectory) }
                }
            }
            .padding(14)
            Divider()
            HStack {
                Text(model.status).font(.caption)
                Spacer()
                Text("\(model.candidates.count) candidates · \(model.visited) items").font(.caption.monospacedDigit())
            }
            .padding(12)
            if model.candidates.isEmpty {
                ContentUnavailableView("No candidates", systemImage: "sparkle.magnifyingglass",
                    description: Text(model.isScanning ? "Scanning the remote directory…" : model.status))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.candidates) { candidate in
                    HStack(spacing: 10) {
                        Toggle(candidate.item.name, isOn: Binding(
                            get: { model.selectedIDs.contains(candidate.id) },
                            set: { selected in
                                if selected { model.selectedIDs.insert(candidate.id) }
                                else { model.selectedIDs.remove(candidate.id) }
                            }
                        )).labelsHidden()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.item.name).font(.body)
                            Text(candidate.url.absoluteString).font(.caption.monospaced()).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text(candidate.category).font(.caption)
                        Text(candidate.reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            HStack {
                Text("Review every candidate before deleting.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Delete \(model.selectedIDs.count) selected…", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(model.selectedIDs.isEmpty || model.isScanning || model.isDeleting)
            }
            .padding(12)
        }
        .task { model.start(path: searchDirectory) }
        .onDisappear { model.stop() }
        .confirmationDialog("Delete selected remote items permanently?", isPresented: $showDeleteConfirmation) {
            Button("Delete permanently", role: .destructive) { model.deleteSelected() }
        } message: {
            Text("This server may not have a Trash. \(model.selectedIDs.count) selected items will be deleted.")
        }
    }
}
