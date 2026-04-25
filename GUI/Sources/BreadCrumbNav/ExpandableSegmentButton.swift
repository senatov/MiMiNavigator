// ExpandableSegmentButton.swift
// MiMiNavigator
//
// Created by Claude on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Breadcrumb segment that expands to full name on hover (Finder-style).
//   Truncated segments spring-animate to reveal the complete directory name
//   when the cursor approaches, then collapse back when cursor leaves.

import AppKit
import SwiftUI

// MARK: - ExpandableSegmentButton

struct ExpandableSegmentButton: View {

    let segment: BreadCrumbView.DisplaySegment
    let textColor: Color      // breadcrumbText(Active|Inactive) from theme
    let variableTextColor: Color
    let variableItalic: Bool
    let fontSize: CGFloat     // breadcrumbFontSize from theme
    let onTap: () -> Void
    let helpText: String
    let copyAction: () -> Void

    @State private var isHovered = false

    /// Show full name when hovered and segment is truncated
    private var displayText: String {
        (isHovered && segment.isTruncated) ? segment.fullName : segment.text
    }

    private var displayColor: Color {
        segment.isEnvironmentVariable ? variableTextColor : textColor
    }

    private var displayFont: Font {
        let base = Font.system(size: fontSize, weight: .regular, design: .rounded)
        return segment.isEnvironmentVariable && variableItalic ? base.italic() : base
    }

    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(displayFont)
                .foregroundStyle(displayColor)
                .kerning(0.1)
                .padding(.vertical, 2)
                .padding(.horizontal, isHovered && segment.isTruncated ? 4 : 0)
                .lineLimit(1)
                .fixedSize()
                .background(
                    Group {
                        if isHovered && segment.isTruncated {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .zIndex(isHovered ? 10 : 0)
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
