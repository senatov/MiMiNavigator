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
    private let tabHeight: CGFloat = 29
    private let minTabWidth: CGFloat = 92
    private let maxTabWidth: CGFloat = 210
    private let cornerRadius: CGFloat = 5

    // MARK: - Body

    var body: some View {
        tabContent
            .frame(height: tabHeight)
            .background(tabFill)
            .clipShape(tabShape)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
            .overlay(tabGlassHighlight)
            .overlay(tabBorder)
            .shadow(color: tabOuterShadowColor, radius: isActive ? 2.2 : 1.1, x: 0, y: isActive ? -1 : 0)
            .shadow(color: tabLowerShadowColor, radius: isActive ? 1.5 : 0.8, x: 0, y: isActive ? 1 : 0)
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
                        ? Color(nsColor: .systemGreen)
                        : inactiveForeground.opacity(0.72)
                )
                .frame(width: 14)

            Text(tab.truncatedDisplayName(maxLength: 16))
                .font(.system(size: 13, weight: isActive ? .medium : .regular, design: .default))
                .lineLimit(1)
                .foregroundStyle(isActive ? activeForeground : inactiveForeground)
                .shadow(color: activeTextHighlight, radius: 0, x: 0, y: isActive ? 1 : 0)
                .shadow(color: activeTextShade, radius: 0, x: 0, y: isActive ? -0.5 : 0)

            Spacer(minLength: 0)

            // Close button — always reserves space, visible on hover/active
            closeButton
        }
        .padding(.leading, 11)
        .padding(.trailing, isActive ? 8 : 6)
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
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.82 : 1), location: 0),
                    .init(color: Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.62 : 0.98), location: 0.58),
                    .init(color: Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.18 : 0.10), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isHovered {
            LinearGradient(
                stops: [
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.46 : 0.82), location: 0),
                    .init(color: Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.34 : 0.70), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.28 : 0.58), location: 0),
                    .init(color: Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.20 : 0.42), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var activeForeground: Color {
        isPanelFocused ? Color(nsColor: .systemGreen).opacity(0.88) : Color(nsColor: .darkGray)
    }

    private var inactiveForeground: Color {
        colorScheme == .dark
            ? Color(nsColor: .tertiaryLabelColor)
            : Color(nsColor: .darkGray)
    }

    private var activeTextHighlight: Color {
        isActive && isPanelFocused ? Color.white.opacity(colorScheme == .dark ? 0.10 : 0.62) : .clear
    }

    private var activeTextShade: Color {
        isActive && isPanelFocused ? Color.black.opacity(colorScheme == .dark ? 0.34 : 0.13) : .clear
    }

    private var tabOuterShadowColor: Color {
        isActive
            ? Color.white.opacity(colorScheme == .dark ? 0.05 : 0.62)
            : Color.white.opacity(colorScheme == .dark ? 0.02 : 0.28)
    }

    private var tabLowerShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.36 : isActive ? 0.20 : 0.12)
    }

    private var tabBorder: some View {
        tabShape
            .stroke(
                isActive
                    ? Color(nsColor: .separatorColor).opacity(isPanelFocused ? 0.95 : 0.72)
                    : Color(nsColor: .separatorColor).opacity(isHovered ? 0.72 : 0.56),
                lineWidth: isActive ? 1.15 : 0.95
            )
    }

    private var tabGlassHighlight: some View {
        tabShape
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(colorScheme == .dark ? 0.18 : 0.88), location: 0),
                        .init(color: Color.white.opacity(0.10), location: 0.42),
                        .init(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.10), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
            .padding(0.8)
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
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
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
