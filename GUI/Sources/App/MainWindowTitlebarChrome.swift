// MainWindowTitlebarChrome.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Configurable main-window titlebar fill and perimeter.

import AppKit
import SwiftUI

// MARK: - Window Toolbar Appearance Defaults
enum WindowToolbarAppearanceDefaults {
    static let background = Color(#colorLiteral(red: 0.9843137255, green: 0.9960784314, blue: 0.9882352941, alpha: 1))
    static let border = Color(#colorLiteral(red: 0.6627450980, green: 0.6627450980, blue: 0.6627450980, alpha: 1))
    static let borderWidth = 1.5
}

// MARK: - Main Window Titlebar Chrome
struct MainWindowTitlebarChrome: NSViewRepresentable {
    @AppStorage("windowToolbar.backgroundColor") private var backgroundHex = ""
    @AppStorage("windowToolbar.borderColor") private var borderHex = ""
    @AppStorage("windowToolbar.borderWidth") private var borderWidth = WindowToolbarAppearanceDefaults.borderWidth

    // MARK: - Make View
    func makeNSView(context: Context) -> TitlebarChromeProbe {
        TitlebarChromeProbe()
    }

    // MARK: - Update View
    func updateNSView(_ view: TitlebarChromeProbe, context: Context) {
        view.configure(
            background: NSColor(Color(hex: backgroundHex) ?? WindowToolbarAppearanceDefaults.background),
            border: NSColor(Color(hex: borderHex) ?? WindowToolbarAppearanceDefaults.border),
            width: CGFloat(borderWidth)
        )
    }

    // MARK: - Dismantle View
    static func dismantleNSView(_ view: TitlebarChromeProbe, coordinator: ()) {
        view.removeChrome()
    }
}

// MARK: - Titlebar Chrome Probe
final class TitlebarChromeProbe: NSView {
    private var fillColor = NSColor(WindowToolbarAppearanceDefaults.background)
    private var strokeColor = NSColor(WindowToolbarAppearanceDefaults.border)
    private var strokeWidth = CGFloat(WindowToolbarAppearanceDefaults.borderWidth)
    private var outline: TitlebarOutlineView?
    private var resizeObserver: Any?

    // MARK: - Configure
    func configure(background: NSColor, border: NSColor, width: CGFloat) {
        fillColor = background
        strokeColor = border
        strokeWidth = width
        applyChrome()
    }

    // MARK: - Window Attachment
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeChrome()
        applyChrome()
    }

    // MARK: - Apply Chrome
    private func applyChrome() {
        guard let window, let frameView = window.contentView?.superview else { return }
        window.titlebarAppearsTransparent = true
        window.backgroundColor = fillColor
        if outline == nil {
            let newOutline = TitlebarOutlineView(frame: .zero)
            frameView.addSubview(newOutline, positioned: .above, relativeTo: nil)
            outline = newOutline
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.layoutOutline() }
            }
        }
        outline?.strokeColor = strokeColor
        outline?.strokeWidth = strokeWidth
        layoutOutline()
    }

    // MARK: - Layout Outline
    private func layoutOutline() {
        guard let window, let frameView = window.contentView?.superview, let outline else { return }
        let titlebarHeight = max(40, window.frame.height - window.contentLayoutRect.maxY)
        let y = frameView.isFlipped ? 0 : frameView.bounds.height - titlebarHeight
        outline.frame = NSRect(x: 0, y: y, width: frameView.bounds.width, height: titlebarHeight)
    }

    // MARK: - Remove Chrome
    func removeChrome() {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }
        outline?.removeFromSuperview()
        outline = nil
    }
}

// MARK: - Titlebar Outline View
private final class TitlebarOutlineView: NSView {
    var strokeColor: NSColor = .clear { didSet { needsDisplay = true } }
    var strokeWidth: CGFloat = 0 { didSet { needsDisplay = true } }

    // MARK: - Draw
    override func draw(_ dirtyRect: NSRect) {
        guard strokeWidth > 0 else { return }
        strokeColor.setStroke()
        let inset = strokeWidth / 2
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: 11, yRadius: 11)
        path.lineWidth = strokeWidth
        path.stroke()
    }

    // MARK: - Hit Testing
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
