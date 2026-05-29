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
    @State private var lastLoggedHover = false

    /// Show full name when hovered and segment is truncated.
    private var displayText: String {
        guard isHovered else { return segment.text }
        return segment.isTruncated ? expandedText : segment.text
    }

    private var expandedText: String {
        segment.isCollapsedChain ? segment.fullName : segment.fullName
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
            label
        }
        .buttonStyle(.plain)
        .help(helpText)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .scaleEffect(isHovered ? 1.07 : 1.0, anchor: .center)
        .zIndex(isHovered ? 100 : 0)
        .onHover { hovering in
            setHover(hovering)
        }
        .onContinuousHover { phase in
            switch phase {
                case .active:
                    setHover(true)
                case .ended:
                    setHover(false)
            }
        }
        .contextMenu {
            Button("Copy path", action: copyAction)
        }
    }

    private var label: some View {
        Text(displayText)
            .font(displayFont)
            .foregroundStyle(displayColor)
            .kerning(0)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.vertical, isHovered ? 5 : 3)
            .padding(.horizontal, isHovered ? 9 : 4)
            .fixedSize(horizontal: true, vertical: false)
            .background(hoverBubble)
            .overlay(hoverGlow)
    }

    @ViewBuilder
    private var hoverBubble: some View {
        if isHovered {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(#colorLiteral(red: 0.68, green: 0.80, blue: 0.92, alpha: 0.42)))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color(#colorLiteral(red: 0.28, green: 0.42, blue: 0.58, alpha: 0.36)), radius: 8, x: 0, y: 3)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var hoverGlow: some View {
        if isHovered {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(#colorLiteral(red: 0.82, green: 0.91, blue: 1.0, alpha: 0.74)), lineWidth: 1)
        }
    }

    // MARK: - Hover
    private func setHover(_ hovering: Bool) {
        guard isHovered != hovering else { return }
        if lastLoggedHover != hovering {
            log.debug("[BreadCrumb] hover \(hovering ? "enter" : "exit") index=\(segment.originalIndex) text='\(segment.fullName)'")
            lastLoggedHover = hovering
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.68)) {
            isHovered = hovering
        }
    }
}
