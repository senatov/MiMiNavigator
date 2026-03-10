// ExpandableSegmentButton.swift
// MiMiNavigator
//
// Created by Claude on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Breadcrumb segment that expands to full name on hover (Finder-style).
//   Truncated segments spring-animate to reveal the complete directory name
//   when the cursor approaches, then collapse back when cursor leaves.

import SwiftUI

// MARK: - ExpandableSegmentButton

struct ExpandableSegmentButton: View {

    let segment: BreadCrumbView.DisplaySegment
    let symlinkColor: Color
    let onTap: () -> Void
    let helpText: String
    let copyAction: () -> Void

    @State private var isHovered = false

    /// Show full name when hovered and segment is truncated
    private var displayText: String {
        (isHovered && segment.isTruncated) ? segment.fullName : segment.text
    }

    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(.callout)
                .foregroundStyle(symlinkColor)
                .padding(.vertical, 2)
                .padding(.horizontal, isHovered && segment.isTruncated ? 4 : 0)
                .lineLimit(1)
                .fixedSize()  // allow text to expand beyond layout
                .background(
                    Group {
                        if isHovered && segment.isTruncated {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .zIndex(isHovered ? 10 : 0)  // expanded label on top of neighbors
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Copy path", action: copyAction)
        }
    }
}
