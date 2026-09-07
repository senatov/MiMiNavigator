// ExpandableSegmentButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Animated expanding breadcrumb segment with a raised glass surface and directory actions.

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
    let isCurrent: Bool
    let directoryURL: URL?
    let openOtherPanel: () -> Void
    let openNewTab: () -> Void
    let navigateToChild: (URL) -> Void

    @State private var isHovered = false
    @State private var lastLoggedHover = false
    @State private var showsSubfolders = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lensCornerRadius: CGFloat = 10
    /// Show full name when hovered and segment is truncated.
    private var displayText: String {
        isHovered ? segment.fullName : segment.text
    }

    private var displayColor: Color {
        if isHovered { return hoverTextColor }
        return segment.isEnvironmentVariable ? variableTextColor : textColor
    }

    private var displayFont: Font {
        let requestedSize = isHovered ? hoverFontSize : fontSize
        let resolvedSize = (requestedSize * 2).rounded() / 2
        let base = Font.system(size: resolvedSize, weight: isHovered || isCurrent ? .medium : .regular, design: .default)
        return segment.isEnvironmentVariable && variableItalic ? base.italic() : base
    }

    // MARK: - Body
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
            if directoryURL != nil {
                Divider()
                Button("Open in other panel", action: openOtherPanel)
                Button("Open in new tab", action: openNewTab)
                Divider()
                Button("Show subfolders…") { showsSubfolders = true }
            }
        }
        .popover(isPresented: $showsSubfolders) {
            if let directoryURL {
                BreadcrumbSubfoldersView(directory: directoryURL) { url in
                    showsSubfolders = false
                    navigateToChild(url)
                }
            }
        }
    }

    // MARK: - Expanding label
    private var label: some View {
        Text(displayText)
            .font(displayFont)
            .foregroundStyle(displayColor)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.vertical, isHovered ? 7 : 3)
            .padding(.horizontal, isHovered ? 14 : 4)
            .fixedSize(horizontal: true, vertical: false)
            .background { raisedSurface.opacity(isHovered ? 1 : 0) }
            .padding(.horizontal, isHovered ? 3 : 0)
            .zIndex(isHovered ? 1_000 : 0)
    }

    // MARK: - Raised glass surface
    private var raisedSurface: some View {
        RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.70), hoverBackgroundColor.opacity(0.70), hoverBackgroundColor.opacity(0.90)],
                        startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: lensCornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [Color.white.opacity(0.95), hoverBorderColor.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: lensCornerRadius - 1, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.5)
                    .padding(1)
            }
            .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 2)
            .shadow(color: hoverBorderColor.opacity(0.22), radius: 6, x: 0, y: 4)
    }

    // MARK: - Hover
    private func setHover(_ hovering: Bool) {
        guard isHovered != hovering else { return }
        if lastLoggedHover != hovering {
            log.debug("[BreadCrumb] hover \(hovering ? "enter" : "exit") index=\(segment.originalIndex) text='\(segment.fullName)'")
            lastLoggedHover = hovering
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82)) {
            isHovered = hovering
        }
    }
}
