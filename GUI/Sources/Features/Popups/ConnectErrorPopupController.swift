// ConnectErrorPopupController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Yellow HUD popup showing full connection error diagnostics.
//   Same style as FileInfoPopupController — NSPanel, light yellow bg,
//   thin crisp fonts, selectable text, fade-in/out, ESC/click-outside dismiss.
//   Triggered by the ⚠ button next to connection status in ConnectToServerView.

import AppKit
import Foundation

// MARK: - ConnectErrorPopupController

@MainActor
final class ConnectErrorPopupController {

    static let shared = ConnectErrorPopupController()

    private var panel: NSPanel?
    private var textView: NSTextView?
    private var monitors = PopupEventMonitors()

    private init() {}

    // MARK: - Colors / fonts  (same palette as FileInfoPopupController)
    private static let bgColor     = NSColor(calibratedRed: 1.0,  green: 0.98, blue: 0.88, alpha: 0.97)
    private static let borderColor = NSColor(calibratedRed: 0.78, green: 0.74, blue: 0.58, alpha: 0.6)
    private static let titleColor  = NSColor(calibratedRed: 0.55, green: 0.10, blue: 0.05, alpha: 1.0)
    private static let labelColor  = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.38, alpha: 1.0)
    private static let valueColor  = NSColor.black
    private static let titleFont   = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
    private static let labelFont   = NSFont.systemFont(ofSize: 11,   weight: .medium)
    private static let valueFont   = NSFont.systemFont(ofSize: 11.5, weight: .light)

    // MARK: - Show

    /// server: latest RemoteServer snapshot with lastResult / lastErrorDetail filled
    func show(server: RemoteServer, anchorFrame: CGRect) {
        if panel == nil { buildPanel() }
        guard let panel, let textView, let window = NSApp.keyWindow else { return }

        let attributed = buildContent(server: server)
        textView.textStorage?.setAttributedString(attributed)

        let panelW: CGFloat = 360
        textView.frame.size.width = panelW - 20
        textView.sizeToFit()
        let panelH = min(textView.frame.height + 20, 380)

        let winH = window.frame.height
        let ptInScreen = window.convertPoint(
            toScreen: NSPoint(x: anchorFrame.minX, y: winH - anchorFrame.maxY)
        )
        let target = NSRect(
            x: ptInScreen.x - panelW + anchorFrame.width,
            y: ptInScreen.y - panelH - 6,
            width: panelW, height: panelH
        )

        if panel.isVisible {
            panel.setFrame(target, display: true)
            textView.textStorage?.setAttributedString(attributed)
            return
        }

        let start = NSRect(x: target.origin.x, y: target.origin.y + 8,
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

    // MARK: - Hide

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


    // MARK: - Build content

    private func buildContent(server: RemoteServer) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byWordWrapping
        para.paragraphSpacing = 3

        // Title
        out.append(str: "Connection Failed\n", font: Self.titleFont, color: Self.titleColor, para: para)

        // Server info
        addField(out, label: "Host",     value: "\(server.host):\(server.port)", para: para)
        addField(out, label: "Protocol", value: server.remoteProtocol.rawValue,  para: para)
        addField(out, label: "User",     value: server.user.isEmpty ? "—" : server.user, para: para)
        addField(out, label: "Status",   value: server.lastResult.rawValue,      para: para)

        // Error detail
        if let detail = server.lastErrorDetail, !detail.isEmpty {
            out.append(str: "\nError detail:\n", font: Self.labelFont, color: Self.labelColor, para: para)
            out.append(str: detail + "\n",       font: Self.valueFont, color: Self.valueColor, para: para)
        }

        // Tips based on result type
        let tip: String
        switch server.lastResult {
        case .authFailed: tip = "Check username / password / SSH key."
        case .timeout:    tip = "Host unreachable or firewall blocking port \(server.port)."
        case .refused:    tip = "Service not running on \(server.host):\(server.port)."
        default:          tip = "Check host, port, credentials, VPN, firewall."
        }
        out.append(str: "\nTip: \(tip)\n", font: Self.labelFont, color: Self.labelColor, para: para)

        return out
    }

    private func addField(
        _ result: NSMutableAttributedString,
        label: String, value: String,
        para: NSParagraphStyle
    ) {
        result.append(str: label + ": ", font: Self.labelFont, color: Self.labelColor, para: para)
        result.append(str: value + "\n", font: Self.valueFont, color: Self.valueColor, para: para)
    }


    // MARK: - Build NSPanel

    private func buildPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask: [.nonactivatingPanel],
            backing: .buffered, defer: true
        )
        p.isFloatingPanel = true
        p.hidesOnDeactivate = true
        p.hasShadow = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.bgColor.cgColor
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true
        container.layer?.borderColor = Self.borderColor.cgColor
        container.layer?.borderWidth = 0.5
        p.contentView = container

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])

        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.isRichText = true
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        scroll.documentView = tv

        self.panel = p
        self.textView = tv
    }

}

// MARK: - NSMutableAttributedString convenience

private extension NSMutableAttributedString {
    func append(str: String, font: NSFont, color: NSColor, para: NSParagraphStyle) {
        append(NSAttributedString(string: str, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: para,
        ]))
    }
}
