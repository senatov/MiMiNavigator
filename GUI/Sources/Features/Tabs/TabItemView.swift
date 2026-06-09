// TabItemView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single bottom tab with glass-friendly compact styling.

import SwiftUI

// MARK: - Tab Item View
struct TabItemView: View {

    let tab: TabItem
    let panelSide: FavPanelSide
    let isActive: Bool
    let isPanelFocused: Bool
    let isOnlyTab: Bool
    let tabCount: Int
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void
    let onDuplicate: () -> Void

    @State private var isHovered = false
    @State private var anchorFrame: CGRect = .zero
    @State private var tooltipTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Layout constants
    private let tabHeight: CGFloat = 27
    private let minTabWidth: CGFloat = 132
    private let maxTabWidth: CGFloat = 260
    private let cornerRadius: CGFloat = 9

    // MARK: - Body

    var body: some View {
        tabContent
            .frame(height: tabHeight)
            .background(tabFill)
            .clipShape(tabShape)
            .overlay(tabGlassHighlight)
            .overlay(tabBorder)
            .shadow(color: tabOuterShadowColor, radius: isActive ? 2.0 : 1.0, x: 0, y: -0.6)
            .shadow(color: tabLowerShadowColor, radius: isActive ? 4.5 : 2.4, x: 0, y: isActive ? 3.0 : 1.8)
            .background(frameReader)
            .onTapGesture { onSelect() }
            .onHover(perform: handleHover)
            .contextMenu {
                TabContextMenu(
                    tab: tab,
                    isOnlyTab: isOnlyTab,
                    tabCount: tabCount,
                    onClose: onClose,
                    onCloseOthers: onCloseOthers,
                    onCloseToRight: onCloseToRight,
                    onDuplicate: onDuplicate
                )
            }
        .animation(.easeOut(duration: 0.15), value: isActive)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Tab Content

    private var tabContent: some View {
        HStack(spacing: 5) {
            // Favicon-style folder icon
            Image(systemName: tab.isArchive ? "doc.zipper" : "folder.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? activeForeground
                        : inactiveForeground.opacity(0.72)
                )
                .frame(width: 14)

            Text(tab.truncatedDisplayName(maxLength: 22))
                .font(.system(size: 12.5, weight: isActive ? .medium : .regular, design: .default))
                .lineLimit(1)
                .foregroundStyle(isActive ? activeForeground : inactiveForeground)
                .shadow(color: activeTextHighlight, radius: 0, x: 0, y: isActive ? 1 : 0)
                .shadow(color: activeTextShade, radius: 0, x: 0, y: isActive ? -0.5 : 0)

            Spacer(minLength: 0)

            // Close button — always reserves space, visible on hover/active
            closeButton
        }
        .padding(.leading, 13)
        .padding(.trailing, isActive ? 9 : 7)
        .frame(minWidth: minTabWidth, maxWidth: maxTabWidth)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: {
            log.debug("[TabItemView] close '\(tab.displayName)'")
            onClose()
        }) {
            ZStack {
                Circle()
                    .fill(
                        isHovered
                            ? Color.secondary.opacity(0.2)
                            : Color.clear
                    )
                    .frame(width: 16, height: 16)

                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.secondary)
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .opacity((isActive || isHovered) && !isOnlyTab ? 1.0 : 0.0)
        .frame(width: 16)  // always occupies space to avoid layout shift
    }

    // MARK: - Tab Fill

    @ViewBuilder
    private var tabFill: some View {
        if isActive {
            LinearGradient(
                stops: [
                    .init(color: activeFillTop.opacity(colorScheme == .dark ? 0.72 : 1), location: 0),
                    .init(color: activeFillMid.opacity(colorScheme == .dark ? 0.54 : 0.98), location: 0.66),
                    .init(color: activeFillFoot.opacity(colorScheme == .dark ? 0.32 : 0.92), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isHovered {
            LinearGradient(
                stops: [
                    .init(color: inactiveFillTop.opacity(colorScheme == .dark ? 0.32 : 0.72), location: 0),
                    .init(color: inactiveFillFoot.opacity(colorScheme == .dark ? 0.26 : 0.64), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: inactiveFillTop.opacity(colorScheme == .dark ? 0.24 : 0.54), location: 0),
                    .init(color: inactiveFillFoot.opacity(colorScheme == .dark ? 0.18 : 0.46), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var activeForeground: Color {
        isPanelFocused ? activeNavy : Color(nsColor: .darkGray)
    }

    private var inactiveForeground: Color {
        colorScheme == .dark
            ? Color(nsColor: .tertiaryLabelColor)
            : Color(nsColor: .darkGray)
    }

    private var activeTextHighlight: Color {
        isActive && isPanelFocused ? Color.white.opacity(colorScheme == .dark ? 0.08 : 0.48) : .clear
    }

    private var activeTextShade: Color {
        isActive && isPanelFocused ? activeNavy.opacity(colorScheme == .dark ? 0.42 : 0.18) : .clear
    }

    private var tabOuterShadowColor: Color {
        isActive
            ? Color.white.opacity(colorScheme == .dark ? 0.04 : 0.44)
            : Color.white.opacity(colorScheme == .dark ? 0.02 : 0.20)
    }

    private var tabLowerShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.38 : isActive ? 0.26 : 0.17)
    }

    private var tabBorder: some View {
        tabShape
            .stroke(
                isActive
                    ? activeBorder.opacity(isPanelFocused ? 0.86 : 0.66)
                    : inactiveBorder.opacity(isHovered ? 0.68 : 0.52),
                lineWidth: isActive ? 1.0 : 0.9
            )
    }

    private var tabGlassHighlight: some View {
        tabShape
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.72), location: 0),
                        .init(color: Color.white.opacity(0.08), location: 0.48),
                        .init(color: activeNavy.opacity(colorScheme == .dark ? 0.20 : 0.10), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
            .padding(0.8)
    }

    private var activeNavy: Color {
        Color(#colorLiteral(red: 0.018, green: 0.071, blue: 0.204, alpha: 1))
    }

    private var activeBorder: Color {
        Color(#colorLiteral(red: 0.333, green: 0.451, blue: 0.651, alpha: 1))
    }

    private var activeFillTop: Color {
        Color(#colorLiteral(red: 0.965, green: 0.984, blue: 1.0, alpha: 1))
    }

    private var activeFillMid: Color {
        Color(#colorLiteral(red: 0.886, green: 0.929, blue: 0.988, alpha: 1))
    }

    private var activeFillFoot: Color {
        Color(#colorLiteral(red: 0.745, green: 0.819, blue: 0.925, alpha: 1))
    }

    private var inactiveFillTop: Color {
        Color(#colorLiteral(red: 0.875, green: 0.902, blue: 0.936, alpha: 1))
    }

    private var inactiveFillFoot: Color {
        Color(#colorLiteral(red: 0.722, green: 0.776, blue: 0.842, alpha: 1))
    }

    private var inactiveBorder: Color {
        Color(#colorLiteral(red: 0.455, green: 0.536, blue: 0.642, alpha: 1))
    }

    private var frameReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    anchorFrame = geo.frame(in: .global)
                }
                .onChange(of: geo.frame(in: .global)) { _, frame in
                    anchorFrame = frame
                }
        }
    }

    private var tabShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: 4,
            bottomTrailingRadius: 4,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        tooltipTask?.cancel()
        if hovering {
            tooltipTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(430))
                guard isHovered else { return }
                TabTooltipPopupController.shared.show(
                    tab: tab,
                    panelSide: panelSide,
                    isActive: isActive,
                    anchorFrame: anchorFrame
                )
            }
        } else {
            tooltipTask = nil
            TabTooltipPopupController.shared.hide(immediate: true, reason: "tab hover ended")
        }
    }
}
