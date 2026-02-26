// ToolbarButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Toolbar button components — macOS 26 HIG, crisp SF Symbols.
//   Uses NSWindow-based tooltip that floats above everything and never clips.
//   Works around .help() being broken in .windowToolbarStyle(.unifiedCompact).

import AppKit
import SwiftUI

// MARK: - Shared icon style
private struct ToolbarIcon: View {
    let name: String
    var active: Bool = false

    var body: some View {
        Image(systemName: name)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? Color.accentColor : Color.primary)
    }
}

// MARK: - Floating Tooltip Window (AppKit-based, never clips)

/// Singleton tooltip window — lightweight NSPanel that floats above all content.
@MainActor
private final class TooltipWindow {
    static let shared = TooltipWindow()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    private init() {}

    func show(text: String, near screenPoint: NSPoint) {
        hide()

        let label = AnyView(
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        )

        let hosting = NSHostingView(rootView: label)
        hosting.frame.size = hosting.fittingSize
        self.hostingView = hosting

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.hasShadow = false
        p.contentView = hosting
        p.isReleasedWhenClosed = false
        p.animationBehavior = .utilityWindow
        p.ignoresMouseEvents = true

        // Position: centered below the hover point, clamped to screen
        let size = hosting.fittingSize
        var origin = NSPoint(
            x: screenPoint.x - size.width / 2,
            y: screenPoint.y - size.height - 4
        )

        // Clamp to visible screen
        if let screen = NSScreen.main?.visibleFrame {
            if origin.x + size.width > screen.maxX {
                origin.x = screen.maxX - size.width - 4
            }
            if origin.x < screen.minX {
                origin.x = screen.minX + 4
            }
            if origin.y < screen.minY {
                origin.y = screenPoint.y + 20  // show above instead
            }
        }

        p.setFrameOrigin(origin)
        p.orderFront(nil)
        self.panel = p
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }
}

// MARK: - Fast Tooltip Modifier (NSWindow-based)

private struct FastTooltip: ViewModifier {
    let text: String
    @State private var isHovering = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: TooltipFrameKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(TooltipFrameKey.self) { _ in }
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    hoverTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        guard isHovering else { return }
                        // Get mouse location in screen coords
                        let mouseScreen = NSEvent.mouseLocation
                        // Show below mouse
                        TooltipWindow.shared.show(
                            text: text,
                            near: NSPoint(x: mouseScreen.x, y: mouseScreen.y - 20)
                        )
                    }
                } else {
                    hoverTask?.cancel()
                    hoverTask = nil
                    TooltipWindow.shared.hide()
                }
            }
    }
}

private struct TooltipFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private extension View {
    func fastTooltip(_ text: String) -> some View {
        modifier(FastTooltip(text: text))
    }
}

// MARK: - Standard Toolbar Button
struct ToolbarButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(name: systemImage)
        }
        .buttonStyle(.borderless)
        .fastTooltip(help)
    }
}

// MARK: - Toggle Toolbar Button
struct ToolbarToggleButton: View {
    let systemImage: String
    let activeImage: String
    let helpActive: String
    let helpInactive: String
    @Binding var isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(name: isActive ? activeImage : systemImage, active: isActive)
        }
        .buttonStyle(.borderless)
        .fastTooltip(isActive ? helpActive : helpInactive)
    }
}
