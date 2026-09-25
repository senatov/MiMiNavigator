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
    @AppStorage("tabs.appearance.bottomRadius") private var bottomRadius = TabAppearance.bottomRadius

    // MARK: - Layout constants
    private let minTabWidth: CGFloat = 112
    private let maxTabWidth: CGFloat = 236

    // MARK: - Body

    var body: some View {
        tabContent
            .frame(height: TabAppearance.height)
            .background {
                PanelTabSurface(isActive: isActive, isPanelFocused: isPanelFocused, isHovered: isHovered)
            }
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
            TabAppearanceLabel(
                title: tab.truncatedDisplayName(maxLength: 22),
                systemIcon: tab.isArchive ? "doc.zipper" : "folder.fill",
                fileIcon: nativeIcon,
                isSelected: isActive,
                isFocused: isPanelFocused
            )

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
        .opacity(closeButtonVisible ? 1.0 : 0.0)
        .allowsHitTesting(closeButtonVisible)
        .frame(width: 16)  // always occupies space to avoid layout shift
    }

    private var closeButtonVisible: Bool {
        (isActive || isHovered) && !isOnlyTab && UserPreferences.shared.snapshot.tabsShowCloseButton
    }

    private var nativeIcon: NSImage? {
        let iconURL = tab.archiveURL ?? tab.url
        guard iconURL.isFileURL else { return nil }
        return NSWorkspace.shared.icon(forFile: iconURL.path)
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
        BottomSheetTabShape(bottomRadius: CGFloat(bottomRadius))
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
struct BottomSheetTabShape: InsettableShape {
    var bottomRadius: CGFloat = CGFloat(TabAppearance.bottomRadius)
    private var insetAmount: CGFloat = 0

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

    func inset(by amount: CGFloat) -> BottomSheetTabShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
