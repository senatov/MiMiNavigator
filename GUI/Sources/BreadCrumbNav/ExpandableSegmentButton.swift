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

    private let lensCornerRadius: CGFloat = 10
    private let hoverFontScale: CGFloat = 1.13

    /// Show full name when hovered and segment is truncated.
    private var displayText: String {
        guard isHovered else { return segment.text }
        return segment.isTruncated ? expandedText : segment.text
    }

    private var expandedText: String {
        segment.fullName
    }

    private var displayColor: Color {
        segment.isEnvironmentVariable ? variableTextColor : textColor
    }

    private var displayFont: Font {
        let resolvedSize = isHovered ? fontSize * hoverFontScale : fontSize
        let base = Font.system(size: resolvedSize, weight: .regular, design: .rounded)
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
            .kerning(0)
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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous))
                .overlay(lensHighlight)
                .compositingGroup()
                .shadow(color: Color(#colorLiteral(red: 0.12, green: 0.24, blue: 0.38, alpha: 0.34)), radius: 10, x: 0, y: 5)
                .zIndex(1_000)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var hoverGlow: some View {
        if isHovered {
            RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous)
                .stroke(lensStroke, lineWidth: 1.2)
        }
    }

    private var lensFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(#colorLiteral(red: 0.92, green: 0.98, blue: 1.0, alpha: 0.76)),
                Color(#colorLiteral(red: 0.67, green: 0.83, blue: 0.96, alpha: 0.58)),
                Color(#colorLiteral(red: 0.43, green: 0.66, blue: 0.86, alpha: 0.46))
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
                        Color(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.42)),
                        Color(#colorLiteral(red: 0.86, green: 0.94, blue: 1.0, alpha: 0.10)),
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
                Color(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)),
                Color(#colorLiteral(red: 0.34, green: 0.58, blue: 0.78, alpha: 0.66))
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
        withAnimation(.spring(response: 0.24, dampingFraction: 0.68)) {
            isHovered = hovering
        }
    }
}
