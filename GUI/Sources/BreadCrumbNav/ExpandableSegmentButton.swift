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
    let hoverTextColor: Color
    let hoverBackgroundColor: Color
    let hoverBorderColor: Color
    let hoverFontSize: CGFloat
    let onTap: () -> Void
    let helpText: String
    let copyAction: () -> Void

    @State private var isHovered = false
    @State private var lastLoggedHover = false

    private let lensCornerRadius: CGFloat = 10
    /// Show full name when hovered and segment is truncated.
    private var displayText: String {
        guard isHovered else { return segment.text }
        return segment.isTruncated ? expandedText : segment.text
    }

    private var expandedText: String {
        segment.fullName
    }

    private var displayColor: Color {
        if isHovered { return hoverTextColor }
        return segment.isEnvironmentVariable ? variableTextColor : textColor
    }

    private var displayFont: Font {
        let requestedSize = isHovered ? hoverFontSize : fontSize
        let resolvedSize = (requestedSize * 2).rounded() / 2
        let base = Font.system(size: resolvedSize, weight: isHovered ? .medium : .regular, design: .default)
        return segment.isEnvironmentVariable && variableItalic ? base.italic() : base
    }

    var body: some View {
        Button(action: onTap) {
            label
        }
        .buttonStyle(.plain)
        .help(helpText)
        .contentShape(RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous))
        .zIndex(isHovered ? 1_000 : 0)
        .onHover { hovering in
            setHover(hovering)
        }
        .contextMenu {
            Button("Copy path", action: copyAction)
        }
    }

    private var label: some View {
        Text(displayText)
            .font(displayFont)
            .foregroundStyle(displayColor)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.vertical, isHovered ? 6 : 3)
            .padding(.horizontal, isHovered ? 11 : 4)
            .fixedSize(horizontal: true, vertical: false)
            .background(hoverBubble)
            .overlay(hoverGlow)
            .zIndex(isHovered ? 1_000 : 0)
    }

    @ViewBuilder
    private var hoverBubble: some View {
        if isHovered {
            RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous)
                .fill(lensFill)
                .overlay(lensHighlight)
                .shadow(color: Color(#colorLiteral(red: 0.08, green: 0.18, blue: 0.30, alpha: 0.30)), radius: 4, x: 0, y: 2)
                .shadow(color: Color(#colorLiteral(red: 0.12, green: 0.30, blue: 0.48, alpha: 0.16)), radius: 9, x: 0, y: 4)
                .zIndex(1_000)
        }
    }

    @ViewBuilder
    private var hoverGlow: some View {
        if isHovered {
            RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous)
                .strokeBorder(lensStroke, lineWidth: 1)
                .overlay {
                    RoundedRectangle(cornerRadius: lensCornerRadius - 1, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.70), lineWidth: 0.75)
                        .padding(1)
                }
        }
    }

    private var lensFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.88),
                hoverBackgroundColor.opacity(0.78),
                hoverBackgroundColor.opacity(0.66)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var lensHighlight: some View {
        RoundedRectangle(cornerRadius: lensCornerRadius - 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.46)),
                        Color(#colorLiteral(red: 0.86, green: 0.94, blue: 1.0, alpha: 0.08)),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(1)
    }

    private var lensStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.92),
                hoverBorderColor.opacity(0.82)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Hover
    private func setHover(_ hovering: Bool) {
        guard isHovered != hovering else { return }
        if lastLoggedHover != hovering {
            log.debug("[BreadCrumb] hover \(hovering ? "enter" : "exit") index=\(segment.originalIndex) text='\(segment.fullName)'")
            lastLoggedHover = hovering
        }
        isHovered = hovering
    }
}
