// TabItemView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single bottom tab with glass-friendly compact styling.

import AppKit
import SwiftUI

// MARK: - Tab Item View
struct TabItemView: View {

    let tab: TabItem
    let font: NSFont
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

    // MARK: - Body
    var body: some View {
        Button(action: onSelect) {
            TabAppearanceLabel(
                title: tab.displayName,
                systemIcon: tab.isArchive ? "doc.zipper" : "folder",
                compactFont: font,
                isSelected: isActive,
                isFocused: isPanelFocused
            )
            .padding(.horizontal, 7)
            .padding(.trailing, reservesCloseButton ? 17 : 0)
            .frame(minWidth: 56, maxWidth: max(172, font.pointSize * 9), alignment: .leading)
            .frame(height: TabAppearance.compactTabHeight(for: font))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.displayName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .background {
            PanelTabSurface(isActive: isActive, isPanelFocused: isPanelFocused, isHovered: isHovered, compact: true)
        }
        .overlay(alignment: .trailing) {
            if closeButtonVisible {
                closeButton.padding(.trailing, 3)
            }
        }
        .background(frameReader)
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
        .animation(.easeOut(duration: 0.10), value: isActive)
        .animation(.easeOut(duration: 0.12), value: isHovered)
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
        .accessibilityLabel("Close \(tab.displayName)")
    }

    // MARK: - Close Button Visibility
    private var closeButtonVisible: Bool {
        (isActive || isHovered) && reservesCloseButton
    }

    private var reservesCloseButton: Bool {
        !isOnlyTab && UserPreferences.shared.snapshot.tabsShowCloseButton
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

    // MARK: - Hover
    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        tooltipTask?.cancel()
        if hovering {
            tooltipTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(430))
                guard !Task.isCancelled, isHovered else { return }
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
struct BottomSheetTabShape: InsettableShape {
    var bottomRadius: CGFloat = CGFloat(TabAppearance.bottomRadius)
    private var insetAmount: CGFloat = 0

    // MARK: - Path
    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let slope: CGFloat = 6
        let radius = min(bottomRadius, frame.height * 0.45)
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

    // MARK: - Inset
    func inset(by amount: CGFloat) -> BottomSheetTabShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
