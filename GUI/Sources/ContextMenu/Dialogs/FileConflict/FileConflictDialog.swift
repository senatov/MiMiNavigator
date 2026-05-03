// FileConflictDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Windows-style file conflict dialog — warning icon, file info comparison,
//              per-file actions + "Apply to all remaining files" checkbox.

import SwiftUI

// MARK: - File Conflict Dialog

struct FileConflictDialog: View {
    let conflict: FileConflictInfo
    /// how many conflicting files remain in the batch (including this one)
    let remainingCount: Int
    let onResolve: (BatchConflictDecision) -> Void

    @State private var applyToAll = false


    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentSection
            Divider()
            if remainingCount > 1 { applyToAllSection }
            Divider()
            buttonSection
        }
        .frame(width: 640)
        .background(dialogBackground)
        .overlay(dialogBorder)
    }
}


// MARK: - Sections

private extension FileConflictDialog {

    var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.yellow)
                .shadow(color: .orange.opacity(0.3), radius: 2, y: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Replace file?")
                    .font(.system(size: 14, weight: .semibold))
                Text("A file named \"\(conflict.targetName)\" already exists in the destination.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DialogColors.stripe)
    }


    var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose what to do with the incoming file.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                FileInfoRow(
                    title: "Existing in destination",
                    url: conflict.targetURL,
                    name: conflict.targetName,
                    size: conflict.targetSize,
                    date: conflict.targetDate
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                transferArrow
                FileInfoRow(
                    title: "Incoming from source",
                    url: conflict.sourceURL,
                    name: conflict.sourceName,
                    size: conflict.sourceSize,
                    date: conflict.sourceDate
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            comparisonBadge
            Text("Replace Existing overwrites the destination file with the incoming file.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    var transferArrow: some View {
        Image(systemName: "arrow.left")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 54)
            .padding(.top, 18)
    }


    /// shows which file is newer/bigger
    var comparisonBadge: some View {
        HStack(spacing: 16) {
            if let srcDate = conflict.sourceDate, let tgtDate = conflict.targetDate {
                comparisonChip(
                    icon: "clock",
                    text: srcDate > tgtDate ? "Source is newer" : "Target is newer",
                    color: srcDate > tgtDate ? .blue : .orange
                )
            }
            if conflict.sourceSize != conflict.targetSize {
                comparisonChip(
                    icon: "doc",
                    text: sizeDiffText,
                    color: .gray
                )
            }
        }
    }


    var applyToAllSection: some View {
        HStack {
            Toggle(isOn: $applyToAll) {
                Text("Apply to all remaining files (\(remainingCount - 1) more)")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }


    var buttonSection: some View {
        HStack(spacing: 8) {
            // left: Stop
            ConflictButton(title: "Stop", action: { resolve(.stop) })
            Spacer()
            ConflictButton(title: "Skip Incoming", action: { resolve(.skip) })
            ConflictButton(title: "Keep Both", action: { resolve(.keepBoth) })
            ConflictButton(title: "Replace Existing", isPrimary: true, action: { resolve(.replace) })
        }
        .padding(12)
        .background(DialogColors.stripe)
    }
}


// MARK: - Helpers

private extension FileConflictDialog {

    func resolve(_ resolution: ConflictResolution) {
        onResolve(BatchConflictDecision(resolution: resolution, applyToAll: applyToAll))
    }


    func comparisonChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }


    var sizeDiffText: String {
        let diff = abs(conflict.sourceSize - conflict.targetSize)
        let formatted = ByteCountFormatter.string(fromByteCount: diff, countStyle: .file)
        return conflict.sourceSize > conflict.targetSize
            ? "Source is \(formatted) larger"
            : "Target is \(formatted) larger"
    }
}


// MARK: - Styling

private extension FileConflictDialog {

    var dialogBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(DialogColors.base)
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }


    var dialogBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
    }
}


// MARK: - Preview

#Preview {
    FileConflictDialog(
        conflict: FileConflictInfo(
            source: URL(fileURLWithPath: "/Users/senat/Downloads/test.mp4"),
            target: URL(fileURLWithPath: "/private/tmp/test.mp4")
        ),
        remainingCount: 5,
        onResolve: { decision in
            print("resolved: \(decision)")
        }
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
