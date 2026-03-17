// InfoPopupController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Universal floating HUD popup (NSPanel).
//   Light yellow bg, thin crisp fonts, selectable text, fade-in/out, ESC/click-outside dismiss.
//   Base class for all info popups in the app — eliminates panel/scroll/textView duplication.
//   Subclasses override buildContent() to provide attributed text.
//
//   Concrete subclasses:
//     • ConnectInfoPopup  — connection error diagnostics (ConnectToServerView)
//     • FileInfoPopup     — full file metadata (FileInfoPopupController)

import AppKit
import Foundation

// MARK: - InfoPopupController

@MainActor
class InfoPopupController {

    // MARK: - Shared panel palette (all subclasses use the same HUD look)
    static let bgColor     = NSColor(calibratedRed: 1.0,  green: 0.98, blue: 0.88, alpha: 0.97)
    static let borderColor = NSColor(calibratedRed: 0.78, green: 0.74, blue: 0.58, alpha: 0.6)
    static let labelColor  = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.38, alpha: 1.0)
    static let titleColor  = NSColor(calibratedRed: 0.55, green: 0.10, blue: 0.05, alpha: 1.0)
    static let valueColor  = NSColor.black
    static let titleFont   = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
    static let labelFont   = NSFont.systemFont(ofSize: 11,   weight: .medium)
    static let valueFont   = NSFont.systemFont(ofSize: 11.5, weight: .light)
    static let nameFont    = NSFont.systemFont(ofSize: 12.5, weight: .regular)

    // MARK: - Panel infrastructure
    private(set) var panel: NSPanel?
    private(set) var textView: NSTextView?
    var monitors = PopupEventMonitors()

    init() {}

    // MARK: - show(content:anchorFrame:)
    /// Present the popup with pre-built attributed content, anchored below anchorFrame.
    func show(content: NSAttributedString, anchorFrame: CGRect, width: CGFloat = 360) {
        if panel == nil { buildPanel(width: width) }
        guard let panel, let textView,
              let window = NSApp.keyWindow ?? NSApp.mainWindow
        else { return }

        textView.textStorage?.setAttributedString(content)
        textView.frame.size.width = width - 20
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.sizeToFit()
        let panelH = min(max(textView.frame.height + 24, 80), 400)

        let winH = window.frame.height
        let ptInScreen = window.convertPoint(
            toScreen: NSPoint(x: anchorFrame.minX, y: winH - anchorFrame.maxY)
        )
        let target = NSRect(
            x: ptInScreen.x - width + anchorFrame.width,
            y: ptInScreen.y - panelH - 6,
            width: width, height: panelH
        )

        if panel.isVisible {
            panel.setFrame(target, display: true)
            textView.textStorage?.setAttributedString(content)
            return
        }
        let start = NSRect(x: target.minX, y: target.minY + 8,
                           width: target.width, height: target.height)
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        window.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
        monitors.install(panel: panel) { [weak self] in self?.hide() }
    }

    // MARK: - hide
    func hide() {
        monitors.remove()
        guard let panel, panel.isVisible else { return }
        let parent = panel.parent
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.10
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
        })
    }

    // MARK: - buildPanel
    private func buildPanel(width: CGFloat) {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 260),
            styleMask: [.nonactivatingPanel],
            backing: .buffered, defer: true
        )
        p.isFloatingPanel     = true
        p.hidesOnDeactivate   = true
        p.hasShadow           = true
        p.isOpaque            = false
        p.backgroundColor     = .clear
        p.level               = .floating

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.bgColor.cgColor
        container.layer?.cornerRadius    = 8
        container.layer?.masksToBounds   = true
        container.layer?.borderColor     = Self.borderColor.cgColor
        container.layer?.borderWidth     = 0.5
        p.contentView = container

        let scroll = NSScrollView()
        scroll.hasVerticalScroller  = true
        scroll.autohidesScrollers   = true
        scroll.drawsBackground      = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor,       constant:  8),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor,  constant: 10),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])

        let tv = NSTextView()
        tv.isEditable    = false
        tv.isSelectable  = true
        tv.drawsBackground = false
        tv.isRichText    = true
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding  = 0
        tv.textContainer?.widthTracksTextView  = true
        tv.isVerticallyResizable   = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask        = [.width]
        scroll.documentView = tv

        self.panel    = p
        self.textView = tv
    }
}

// MARK: - NSMutableAttributedString convenience (shared by all subclasses)

extension NSMutableAttributedString {

    /// Append a plain segment with font + color + paragraph style.
    func appendHUD(
        _ str: String,
        font: NSFont,
        color: NSColor,
        para: NSParagraphStyle? = nil
    ) {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let para { attrs[.paragraphStyle] = para }
        append(NSAttributedString(string: str, attributes: attrs))
    }

    /// Append a label: value\n pair in the standard HUD style.
    func appendField(
        label: String,
        value: String,
        labelFont: NSFont  = InfoPopupController.labelFont,
        valueFont: NSFont  = InfoPopupController.valueFont,
        labelColor: NSColor = InfoPopupController.labelColor,
        valueColor: NSColor = InfoPopupController.valueColor,
        para: NSParagraphStyle? = nil
    ) {
        appendHUD(label + ": ", font: labelFont, color: labelColor, para: para)
        appendHUD(value + "\n", font: valueFont, color: valueColor, para: para)
    }
}
