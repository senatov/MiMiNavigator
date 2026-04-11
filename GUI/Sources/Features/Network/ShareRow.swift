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
    @State private var isPressed = false

    private enum Layout {
        static let iconWidth: CGFloat = 20
        static let rowSpacing: CGFloat = 8
        static let horizontalPaddingLeading: CGFloat = 44
        static let horizontalPaddingTrailing: CGFloat = 10
        static let verticalPadding: CGFloat = 5
        static let cornerRadius: CGFloat = 10
        static let iconSize: CGFloat = 14
        static let trailingIndicatorSize: CGFloat = 12
        static let pressedScale: CGFloat = 0.992
    }

    private static let activeBorderOpacity: Double = 0.10
    private static let hoverTintOpacity: Double = 0.08
    private static let idleTintOpacity: Double = 0.02
    private static let pressedTintOpacity: Double = 0.11
    private static let idleIndicatorOpacity: Double = 0.22

    private var backgroundTintOpacity: Double {
        if isPressed {
            return Self.pressedTintOpacity
        }
        return isHovered ? Self.hoverTintOpacity : Self.idleTintOpacity
    }

    private var borderOpacity: Double {
        if isHovered || isPressed {
            return Self.activeBorderOpacity
        }
        return Self.activeBorderOpacity * 0.45
    }

    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(
                .regular.tint(
                    Color.accentColor.opacity(backgroundTintOpacity)
                )
            )
    }

    @ViewBuilder
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .strokeBorder(
                Color.white.opacity(borderOpacity),
                lineWidth: 0.8
            )
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        Image(systemName: "arrow.right.circle")
            .font(.system(size: Layout.trailingIndicatorSize))
            .foregroundStyle(isHovered || isPressed ? Color.accentColor : .secondary)
            .opacity(isHovered || isPressed ? 1 : Self.idleIndicatorOpacity)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: "folder.fill.badge.person.crop")
                .font(.system(size: Layout.iconSize))
                .foregroundStyle(.blue.opacity(0.72))
                .frame(width: Layout.iconWidth)
            Text(share.name)
                .font(.callout)
                .lineLimit(1)
                .textSelection(.enabled)
            Spacer()
            trailingIndicator
        }
        .padding(.leading, Layout.horizontalPaddingLeading)
        .padding(.trailing, Layout.horizontalPaddingTrailing)
        .padding(.vertical, Layout.verticalPadding)
        .background(rowBackground)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .scaleEffect(isPressed ? Layout.pressedScale : 1)
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
    }

    var body: some View {
        Button(action: onSelect) {
            rowContent
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                copyToPasteboard(share.name)
            } label: {
                Label("Copy Share Name", systemImage: "doc.on.doc")
            }
            Button {
                copyToPasteboard(share.url.absoluteString)
            } label: {
                Label("Copy Mount URL", systemImage: "link")
            }
        }
    }
}
