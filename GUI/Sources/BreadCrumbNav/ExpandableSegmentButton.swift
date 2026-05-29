// ExpandableSegmentButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
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

    /// Show full name when hovered and segment is truncated.
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
                .padding(.vertical, isHovered ? 4 : 2)
                .padding(.horizontal, isHovered ? 7 : 0)
                .lineLimit(1)
                .fixedSize()
                .background(
                    Group {
                        if isHovered {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(#colorLiteral(red: 0.72, green: 0.82, blue: 0.92, alpha: 0.34)))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color(#colorLiteral(red: 0.78, green: 0.88, blue: 1.0, alpha: 0.58)), lineWidth: 0.8)
                                )
                                .shadow(color: Color(#colorLiteral(red: 0.35, green: 0.5, blue: 0.68, alpha: 0.28)), radius: 7, x: 0, y: 3)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .scaleEffect(isHovered ? 1.08 : 1.0, anchor: .center)
        .zIndex(isHovered ? 10 : 0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.68)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Copy path", action: copyAction)
        }
    }
}
