//
//  DragPreviewPopupView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation
import SwiftUI

struct DragPreviewPopupView: View {
    let files: [CustomFile]
    let panelSide: PanelSide

    private static let maximumVisibleRows = 5
    private static let minimumPopupWidth: CGFloat = 420
    private static let maximumPopupWidth: CGFloat = 1008
    private static let iconSize: CGFloat = 18
    private static let horizontalChromeWidth: CGFloat = 240

    private static let rowDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let rowSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.zeroPadsFractionDigits = false
        return formatter
    }()

    private struct PreviewRow: Identifiable {
        let id: String
        let name: String
        let dateText: String
        let sizeText: String
        let isDirectory: Bool
        let icon: NSImage
    }

    private var visibleRows: [PreviewRow] {
        Array(files.prefix(Self.maximumVisibleRows))
            .map { file in
                let metadata = metadata(for: file)
                return PreviewRow(
                    id: file.urlValue.path,
                    name: file.nameStr,
                    dateText: metadata.dateText,
                    sizeText: metadata.sizeText,
                    isDirectory: file.isDirectory,
                    icon: fileIcon(for: file)
                )
            }
    }

    private var hasMoreRows: Bool {
        files.count > Self.maximumVisibleRows
    }

    private var popupWidth: CGFloat {
        let longestVisibleNameWidth =
            visibleRows
            .map { measuredNameWidth(for: $0.name) }
            .max() ?? 0

        let calculatedWidth = longestVisibleNameWidth + Self.horizontalChromeWidth
        return min(max(calculatedWidth, Self.minimumPopupWidth), Self.maximumPopupWidth)
    }

    private func measuredNameWidth(for text: String) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]

        let measuredWidth = (text as NSString).size(withAttributes: attributes).width
        return ceil(measuredWidth)
    }

    private func fileIcon(for file: CustomFile) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: file.urlValue.path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }

    private var subtitle: String {
        switch panelSide {
            case .left:
                return "From left panel"
            case .right:
                return "From right panel"
        }
    }

    private var summaryText: String {
        files.count == 1 ? "1 item" : "\(files.count) items"
    }

    private var headerSymbolName: String {
        if files.count > 1 {
            return "doc.on.doc.fill"
        }
        return files.first?.isDirectory == true ? "folder.fill" : "doc.fill"
    }

    private func metadata(for file: CustomFile) -> (dateText: String, sizeText: String) {
        do {
            let values = try file.urlValue.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isDirectoryKey,
                .totalFileAllocatedSizeKey,
            ])
            let dateText: String
            if let date = values.contentModificationDate {
                dateText = Self.rowDateFormatter.string(from: date)
            } else {
                dateText = "—"
            }
            let sizeText: String
            if values.isDirectory == true {
                sizeText = "Folder"
            } else if let allocatedSize = values.totalFileAllocatedSize {
                sizeText = Self.rowSizeFormatter.string(fromByteCount: Int64(allocatedSize))
            } else if let fileSize = values.fileSize {
                sizeText = Self.rowSizeFormatter.string(fromByteCount: Int64(fileSize))
            } else {
                sizeText = "—"
            }
            return (dateText, sizeText)
        } catch {
            return (dateText: "—", sizeText: file.isDirectory ? "Folder" : "—")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: headerSymbolName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summaryText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if files.count > 1 {
                    Text("\(files.count)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial.opacity(0.75), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(visibleRows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(nsImage: row.icon)
                            .interpolation(.high)
                            .antialiased(true)
                            .frame(width: Self.iconSize, height: Self.iconSize)

                        Text(row.name)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .shadow(color: .black.opacity(0.08), radius: 0, x: 0, y: 0.5)

                        Spacer(minLength: 8)

                        Text(row.dateText)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                            .shadow(color: .black.opacity(0.06), radius: 0, x: 0, y: 0.5)

                        Text(row.sizeText)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(minWidth: 52, alignment: .trailing)
                            .shadow(color: .black.opacity(0.06), radius: 0, x: 0, y: 0.5)
                    }
                    .padding(.vertical, 0)
                }

                if hasMoreRows {
                    Text(".....")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 22)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .frame(width: popupWidth, alignment: .leading)
    }
}
