// TabTooltipPopupController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact yellow hover popup for panel tab details.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Tab Tooltip Popup Controller
@MainActor
final class TabTooltipPopupController {

    static let shared = TabTooltipPopupController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    private init() {}

    // MARK: - Show Tab Info
    func show(tab: TabItem, panelSide: FavPanelSide, isActive: Bool, anchorFrame: CGRect) {
        hide(immediate: true, reason: "replace")
        let content = TabTooltipView(tab: tab, panelSide: panelSide, isActive: isActive)
        let hosting = NSHostingView(rootView: AnyView(content))
        let maxSize = NSSize(width: 286, height: 160)
        hosting.frame.size = hosting.fittingSize
        hosting.frame.size.width = min(max(hosting.fittingSize.width, 220), maxSize.width)
        hosting.frame.size.height = min(max(hosting.fittingSize.height, 58), maxSize.height)
        hostingView = hosting
        let tooltipPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        tooltipPanel.isFloatingPanel = true
        tooltipPanel.hidesOnDeactivate = true
        tooltipPanel.hasShadow = true
        tooltipPanel.isOpaque = false
        tooltipPanel.backgroundColor = .clear
        tooltipPanel.level = .floating
        tooltipPanel.ignoresMouseEvents = true
        tooltipPanel.contentView = hosting
        tooltipPanel.setFrameOrigin(clampedOrigin(for: hosting.frame.size, anchorFrame: anchorFrame))
        tooltipPanel.alphaValue = 0
        tooltipPanel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            tooltipPanel.animator().alphaValue = 1
        }
        panel = tooltipPanel
    }

    // MARK: - Hide
    func hide(immediate: Bool, reason: String) {
        guard let panel else { return }
        if immediate {
            panel.orderOut(nil)
            self.panel = nil
            hostingView = nil
            return
        }
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.08
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                Task { @MainActor in
                    panel.orderOut(nil)
                    self.panel = nil
                    self.hostingView = nil
                }
            }
        )
    }

    // MARK: - Position
    private func clampedOrigin(for size: NSSize, anchorFrame: CGRect) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let fallback = CGPoint(x: anchorFrame.midX, y: anchorFrame.midY)
        let anchor = mouse == .zero ? NSPoint(x: fallback.x, y: fallback.y) : mouse
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var x = anchor.x - size.width / 2
        var y = anchor.y + 18
        if y + size.height > visible.maxY - 6 {
            y = anchor.y - size.height - 18
        }
        x = min(max(x, visible.minX + 6), visible.maxX - size.width - 6)
        y = min(max(y, visible.minY + 6), visible.maxY - size.height - 6)
        return NSPoint(x: x, y: y)
    }
}

// MARK: - Tab Tooltip View
private struct TabTooltipView: View {
    let tab: TabItem
    let panelSide: FavPanelSide
    let isActive: Bool

    private var panelName: String {
        panelSide == .left ? "Left" : "Right"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: tab.isArchive ? "doc.zipper" : "folder.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tab.isArchive ? Color.orange : Color(nsColor: .systemGreen))
                Text(tab.displayName)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color(nsColor: InfoPopupController.titleColor))
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(panelName)
                Text(isActive ? "Active" : "Inactive")
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Color(nsColor: InfoPopupController.labelColor))
            Text(tab.url.path)
                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(nsColor: .black))
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 286, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: InfoPopupController.bgColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: InfoPopupController.borderColor), lineWidth: 0.8)
        )
    }
}
