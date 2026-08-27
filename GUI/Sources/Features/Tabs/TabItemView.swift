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
    private let minTabWidth: CGFloat = 112
    private let maxTabWidth: CGFloat = 236

    // MARK: - Body

    var body: some View {
        tabContent
            .frame(height: tabHeight)
            .background {
                tabFill
                    .clipShape(tabShape)
                    .shadow(color: tabShadowColor, radius: isActive ? 1.8 : 1.1, x: 0.7, y: 1)
            }
            .overlay(tabInnerHighlight)
            .overlay(tabBorder)
            .contentShape(tabShape)
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
        .zIndex(isActive ? 2 : isHovered ? 1 : 0)
    }

    // MARK: - Tab Content

    private var tabContent: some View {
        HStack(spacing: 5) {
            // Favicon-style folder icon
            Image(systemName: tab.isArchive ? "doc.zipper" : "folder.fill")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(isActive ? activeIconColor : inactiveForeground.opacity(0.72))
                .frame(width: 12)

            Text(tab.truncatedDisplayName(maxLength: 22))
                .font(.system(size: 12, weight: .light))
                .lineLimit(1)
                .foregroundStyle(isActive ? activeForeground : inactiveForeground)

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
                    .font(.system(size: 7, weight: .semibold))
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
                    .init(color: activeFillTop.opacity(colorScheme == .dark ? 0.68 : 1), location: 0),
                    .init(color: activeFillMid.opacity(colorScheme == .dark ? 0.52 : 0.98), location: 0.58),
                    .init(color: activeFillFoot.opacity(colorScheme == .dark ? 0.38 : 0.94), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isHovered {
            LinearGradient(
                stops: [
                    .init(color: inactiveFillTop.opacity(colorScheme == .dark ? 0.30 : 0.64), location: 0),
                    .init(color: inactiveFillFoot.opacity(colorScheme == .dark ? 0.24 : 0.58), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: inactiveFillTop.opacity(colorScheme == .dark ? 0.20 : 0.44), location: 0),
                    .init(color: inactiveFillFoot.opacity(colorScheme == .dark ? 0.15 : 0.38), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var activeForeground: Color {
        isPanelFocused ? activeNavy : Color(nsColor: .darkGray)
    }

    private var activeIconColor: Color {
        tab.isArchive
            ? Color(#colorLiteral(red: 0.902, green: 0.314, blue: 0.184, alpha: 1))
            : Color(#colorLiteral(red: 0.098, green: 0.431, blue: 0.922, alpha: 1))
    }

    private var inactiveForeground: Color {
        colorScheme == .dark
            ? Color(nsColor: .tertiaryLabelColor)
            : Color(nsColor: .darkGray)
    }

    private var tabShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? isActive ? 0.32 : 0.20 : isActive ? 0.18 : 0.10)
    }

    private var tabBorder: some View {
        tabShape
            .strokeBorder(
                isActive
                    ? activeBorder.opacity(isPanelFocused ? 0.94 : 0.72)
                    : inactiveBorder.opacity(isHovered ? 0.72 : 0.52),
                lineWidth: isActive ? 0.8 : 0.65
            )
    }

    private var tabInnerHighlight: some View {
        tabShape.fill(
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(colorScheme == .dark ? 0.10 : isActive ? 0.52 : 0.30), location: 0),
                    .init(color: Color.white.opacity(colorScheme == .dark ? 0.025 : 0.07), location: 0.38),
                    .init(color: Color.clear, location: 0.68),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(1)
        .allowsHitTesting(false)
    }

    private var activeNavy: Color {
        Color(#colorLiteral(red: 0.018, green: 0.071, blue: 0.204, alpha: 1))
    }

    private var activeBorder: Color {
        Color(#colorLiteral(red: 0.25, green: 0.58, blue: 0.93, alpha: 1))
    }

    private var activeFillTop: Color {
        Color(#colorLiteral(red: 0.965, green: 0.984, blue: 1.0, alpha: 1))
    }

    private var activeFillMid: Color {
        Color(#colorLiteral(red: 0.918, green: 0.949, blue: 0.986, alpha: 1))
    }

    private var activeFillFoot: Color {
        Color(#colorLiteral(red: 0.82, green: 0.875, blue: 0.95, alpha: 1))
    }

    private var inactiveFillTop: Color {
        Color(#colorLiteral(red: 0.91, green: 0.925, blue: 0.946, alpha: 1))
    }

    private var inactiveFillFoot: Color {
        Color(#colorLiteral(red: 0.79, green: 0.82, blue: 0.86, alpha: 1))
    }

    private var inactiveBorder: Color {
        Color(#colorLiteral(red: 0.49, green: 0.52, blue: 0.57, alpha: 1))
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

    private var tabShape: BottomSheetTabShape {
        BottomSheetTabShape()
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

// MARK: - Bottom Sheet Tab Shape
private struct BottomSheetTabShape: InsettableShape {
    private var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let slope: CGFloat = 6
        let radius: CGFloat = 6
        var path = Path()
        path.move(to: CGPoint(x: frame.minX + 1, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX - 1, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX - slope, y: frame.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: frame.maxX - slope - radius, y: frame.maxY),
            control: CGPoint(x: frame.maxX - slope, y: frame.maxY)
        )
        path.addLine(to: CGPoint(x: frame.minX + slope + radius, y: frame.maxY))
        path.addQuadCurve(
            to: CGPoint(x: frame.minX + slope, y: frame.maxY - radius),
            control: CGPoint(x: frame.minX + slope, y: frame.maxY)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> BottomSheetTabShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
