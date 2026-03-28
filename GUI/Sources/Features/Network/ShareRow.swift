// ShareRow.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single share/volume row in Network Neighborhood tree.
//   Extracted from NetworkNeighborhoodView.swift for single responsibility.

import AppKit
import SwiftUI


// MARK: - Share row

struct ShareRow: View {
    let share: NetworkShare
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill.badge.person.crop")
                .font(.system(size: 14))
                .foregroundStyle(.blue.opacity(0.7))
                .frame(width: 20)
            Text(share.name)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.leading, 44).padding(.trailing, 10).padding(.vertical, 5)
        .background(isHovered ? Color.accentColor.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(share.name, forType: .string)
            } label: {
                Label("Copy Share Name", systemImage: "doc.on.doc")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(share.url.absoluteString, forType: .string)
            } label: {
                Label("Copy Mount URL", systemImage: "link")
            }
        }
    }
}
