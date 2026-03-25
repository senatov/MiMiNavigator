//
//  ScrollArrowButtons.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Descr: top/bottom arrow btns overlaid on scrollView right edge

import AppKit

// MARK: - ScrollArrowButtons
enum ScrollArrowButtons {

    private static let btnSize: CGFloat = 16
    private static let btnWidth: CGFloat = 12

    // MARK: - install
    /// Add arrow buttons as subviews on the right edge of scrollView
    static func install(on scrollView: NSScrollView) {
        let up = makeButton(symbolName: "chevron.compact.up", action: #selector(ScrollArrowTarget.scrollUp))
        let dn = makeButton(symbolName: "chevron.compact.down", action: #selector(ScrollArrowTarget.scrollDown))
        let target = ScrollArrowTarget(scrollView: scrollView)

        // retain target via objc association
        objc_setAssociatedObject(scrollView, "scrollArrowTarget", target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        up.target = target
        dn.target = target

        up.translatesAutoresizingMaskIntoConstraints = false
        dn.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(up)
        scrollView.addSubview(dn)

        NSLayoutConstraint.activate([
            // top arrow — flush right, at top
            up.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            up.topAnchor.constraint(equalTo: scrollView.topAnchor),
            up.widthAnchor.constraint(equalToConstant: btnWidth),
            up.heightAnchor.constraint(equalToConstant: btnSize),
            // bottom arrow — flush right, at bottom
            dn.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            dn.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            dn.widthAnchor.constraint(equalToConstant: btnWidth),
            dn.heightAnchor.constraint(equalToConstant: btnSize),
        ])
    }

    // MARK: - makeButton
    private static func makeButton(symbolName: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: .zero)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        btn.imageScaling = .scaleProportionallyDown
        btn.contentTintColor = NSColor(white: 0.40, alpha: 0.70)
        btn.action = action
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor(white: 0.85, alpha: 0.20).cgColor
        btn.layer?.cornerRadius = 2
        return btn
    }
}

// MARK: - ScrollArrowTarget
/// Handles arrow button clicks — scrolls one row up/down
final class ScrollArrowTarget: NSObject {
    private weak var scrollView: NSScrollView?
    private let rowH: CGFloat = 21

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
    }

    @objc func scrollUp() {
        guard let sv = scrollView, let doc = sv.documentView else { return }
        var pt = sv.contentView.bounds.origin
        pt.y = max(0, pt.y - rowH)
        doc.scroll(pt)
    }

    @objc func scrollDown() {
        guard let sv = scrollView, let doc = sv.documentView else { return }
        var pt = sv.contentView.bounds.origin
        let maxY = doc.frame.height - sv.contentView.bounds.height
        pt.y = min(maxY, pt.y + rowH)
        doc.scroll(pt)
    }
}
