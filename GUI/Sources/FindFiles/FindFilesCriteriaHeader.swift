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
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.tertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(criteria, id: \.self) { value in
                        Text(value)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if value != criteria.last {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 520)
        .help("Active search criteria")
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
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartHeight == nil { dragStartHeight = clamped(criteriaHeight) }
                    let updatedHeight = clamped((dragStartHeight ?? criteriaHeight) + value.translation.height)
                    if criteriaHeight != updatedHeight { criteriaHeight = updatedHeight }
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
        min(max(value, 250), max(250, totalHeight - 190))
    }
}
