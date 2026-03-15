// FileRow+SizeViews.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.10.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Size column SwiftUI views extracted from FileRow.
//              Spinner, symlink size, directory size, SizeTaskModifier.

import FileModelKit
import SwiftUI

// MARK: - Size Column Views
extension FileRow {

    // MARK: - Size column renderer
    @ViewBuilder
    func sizeColumnView() -> some View {
        if isParentEntry {
            EmptyView()
        } else if file.isSymbolicLink && !file.isSymbolicDirectory {
            symlinkFileSizeView()
        } else if file.isDirectory || file.isSymbolicDirectory {
            directorySizeView()
        } else {
            Text(file.fileSizeFormatted)
        }
    }

    // MARK: - Reusable spinner
    var sizeSpinner: some View {
        ProgressView()
            .controlSize(.mini)
            .scaleEffect(0.6)
            .opacity(0.5)
            .frame(width: 8, height: 8)
    }

    // MARK: - Symlink file size
    @ViewBuilder
    private func symlinkFileSizeView() -> some View {
        Group {
            if let size = file.cachedAppSize, file.sizeIsExact {
                Text(Self.formatSize(size))
                    .foregroundStyle(.secondary)
            } else {
                sizeSpinner
            }
        }
        .modifier(
            SizeTaskModifier(
                id: file.id,
                shouldResetOnDisappear: !file.sizeIsExact,
                reset: { file.sizeCalculationStarted = false },
                work: { await runSymlinkSizeTask() }
            )
        )
    }

    // MARK: - Directory size view
    @ViewBuilder
    private func directorySizeView() -> some View {
        Group {
            if let size = file.cachedAppSize {
                if size == DirectorySizeService.unavailableSize {
                    Text("—").foregroundStyle(.secondary)
                } else if file.sizeIsExact {
                    Text(Self.formatSize(size))
                } else if let shallow = file.cachedShallowSize {
                    Text("~" + Self.formatSize(shallow)).foregroundStyle(.secondary)
                } else {
                    sizeSpinner
                }
            } else if let shallow = file.cachedShallowSize {
                Text("~" + Self.formatSize(shallow)).foregroundStyle(.secondary)
            } else {
                sizeSpinner
            }
        }
        .modifier(
            SizeTaskModifier(
                id: file.id,
                shouldResetOnDisappear: !file.sizeIsExact,
                reset: { file.sizeCalculationStarted = false },
                work: { await runDirectorySizeTask() }
            )
        )
    }
}

// MARK: - SizeTaskModifier
/// Attaches an async size calculation task to a View, resetting on disappear if needed.
struct SizeTaskModifier: ViewModifier {
    let id: AnyHashable
    let shouldResetOnDisappear: Bool
    let reset: () -> Void
    let work: () async -> Void

    func body(content: Content) -> some View {
        content
            .task(id: id, priority: .utility) {
                await work()
            }
            .onDisappear {
                guard shouldResetOnDisappear else { return }
                reset()
            }
    }
}
