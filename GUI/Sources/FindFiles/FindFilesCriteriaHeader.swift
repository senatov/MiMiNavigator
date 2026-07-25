// FindFilesCriteriaHeader.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Active criteria summary and draggable results divider.

import SwiftUI

// MARK: - Active Criteria Header
struct FindFilesCriteriaHeader: View {
    let criteria: [String]

    var body: some View {
        HStack(spacing: 8) {
            Label("Active", systemImage: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(criteria, id: \.self) { value in
                        Text(value)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.75)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }
}

// MARK: - Search Results Split Divider
struct FindFilesSplitDivider: View {
    @Binding var criteriaHeight: CGFloat
    let totalHeight: CGFloat
    @State private var dragStartHeight: CGFloat?
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovered ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor))
            Capsule()
                .fill(isHovered ? Color.accentColor : Color(nsColor: .separatorColor))
                .frame(width: 54, height: isHovered ? 3 : 2)
        }
        .frame(height: 9)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            hovering ? NSCursor.resizeUpDown.push() : NSCursor.pop()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartHeight == nil { dragStartHeight = criteriaHeight }
                    criteriaHeight = clamped((dragStartHeight ?? criteriaHeight) + value.translation.height)
                }
                .onEnded { _ in
                    dragStartHeight = nil
                    MiMiDefaults.shared.set(Double(criteriaHeight), forKey: "findFiles.criteriaPaneHeight")
                }
        )
        .accessibilityLabel("Resize search criteria and results")
        .help("Drag to resize criteria and results")
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 210), max(210, totalHeight - 190))
    }
}
