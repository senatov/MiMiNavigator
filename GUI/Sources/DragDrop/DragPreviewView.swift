// DragPreviewView.swift
// MiMiNavigator
//
// Extracted from FileRow.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Visual drag preview badge for file drag-and-drop

import AppKit
import FileModelKit
import SwiftUI


// MARK: - DragPreviewView
/// Shows file icon + name during drag operations, with optional multi-file badge
struct DragPreviewView: View {
    let file: CustomFile
    var additionalCount: Int = 0


    private var totalCount: Int { additionalCount + 1 }


    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                    .resizable()
                    .frame(width: 32, height: 32)
                if totalCount > 1 {
                    Text("\(totalCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(x: 6, y: -4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(file.nameStr)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if totalCount > 1 {
                    Text("and \(additionalCount) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}
