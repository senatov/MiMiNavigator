//
//  File.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftyBeaver
import UniformTypeIdentifiers
import VLC

@MainActor
extension MediaInfoPanel {
    // MARK: - createPanel
    func createPanel() {
        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: LayoutConstants.panelSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        p.isFloatingPanel = true
        p.collectionBehavior = [.fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.becomesKeyOnlyIfNeeded = false
        p.title = "Media Info"
        p.standardWindowButton(.closeButton)?.keyEquivalent = "\u{1b}"
        p.minSize = LayoutConstants.minPanelSize

        let warmBg = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.92, alpha: 1.0)
        let container = NSView(frame: p.contentView!.bounds)
        container.autoresizingMask = [.width, .height]

        // arrows
        let prevBtn = makeArrowButton(symbolName: "arrowshape.left", action: #selector(prevMedia))
        prevBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(prevBtn)

        let nextBtn = makeArrowButton(symbolName: "arrowshape.right", action: #selector(nextMedia))
        nextBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nextBtn)

        // text scroll
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = warmBg
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let tv = MediaTextView(frame: .zero)
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = true
        tv.importsGraphics = false
        tv.usesFindPanel = true
        tv.isAutomaticLinkDetectionEnabled = false
        tv.linkTextAttributes = [
            .foregroundColor: NSColor(calibratedRed: 0.0, green: 0.2, blue: 0.5, alpha: 1.0), .cursor: NSCursor.pointingHand,
        ]
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = .labelColor
        tv.backgroundColor = warmBg
        tv.textContainerInset = NSSize(width: 12, height: 12)
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "")
        tv.menu = menu
        scrollView.documentView = tv
        container.addSubview(scrollView)

        // image preview — NEVER changes window size
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyDown  // only shrink, never enlarge
        iv.imageAlignment = .alignCenter
        iv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        iv.setContentHuggingPriority(.defaultLow, for: .vertical)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 6
        iv.layer?.masksToBounds = true
        iv.layer?.borderWidth = 0.5
        iv.layer?.borderColor = NSColor.separatorColor.cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        container.addSubview(iv)

        let pv = VLCVideoView()
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.isHidden = true
        pv.wantsLayer = true
        pv.layer?.cornerRadius = 6
        pv.layer?.masksToBounds = true
        pv.layer?.borderWidth = 0.5
        pv.layer?.borderColor = NSColor.separatorColor.cgColor
        container.addSubview(pv)

        // separator + buttons
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        let closeBtn = NSButton(title: "Close", target: self, action: #selector(closeAction))
        let revealBtn = NSButton(title: "Reveal", target: self, action: #selector(revealAction))
        let copyBtn = NSButton(title: "Copy All", target: self, action: #selector(copyAllAction))
        let pathBtn = NSButton(title: "Copy Path", target: self, action: #selector(copyPathAction))
        [closeBtn, revealBtn, copyBtn, pathBtn].forEach { $0.bezelStyle = .rounded }
        pathBtn.toolTip = "Copy file path"
        copyBtn.toolTip = "Copy full info"
        revealBtn.toolTip = "Reveal in Finder"
        closeBtn.toolTip = "Close panel"
        copyBtn.keyEquivalent = "c"
        copyBtn.keyEquivalentModifierMask = [.command, .shift]
        pathBtn.keyEquivalent = "c"
        pathBtn.keyEquivalentModifierMask = [.command, .option]
        revealBtn.keyEquivalent = "r"
        revealBtn.keyEquivalentModifierMask = [.command]

        let stack = NSStackView(views: [pathBtn, copyBtn, revealBtn, closeBtn])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stack.distribution = .gravityAreas
        stack.setHuggingPriority(.required, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        // constraints
        let aw = LayoutConstants.arrowWidth
        NSLayoutConstraint.activate([
            prevBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            prevBtn.topAnchor.constraint(equalTo: container.topAnchor),
            prevBtn.bottomAnchor.constraint(equalTo: separator.topAnchor),
            prevBtn.widthAnchor.constraint(equalToConstant: aw),

            scrollView.leadingAnchor.constraint(equalTo: prevBtn.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),
            scrollView.widthAnchor.constraint(
                equalTo: container.widthAnchor, multiplier: LayoutConstants.textWidthMultiplier, constant: -aw),

            iv.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: LayoutConstants.previewSpacing),
            iv.topAnchor.constraint(equalTo: container.topAnchor, constant: LayoutConstants.previewInsets),
            iv.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -LayoutConstants.previewInsets),
            iv.trailingAnchor.constraint(equalTo: nextBtn.leadingAnchor, constant: -LayoutConstants.previewSpacing),

            pv.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: LayoutConstants.previewSpacing),
            pv.topAnchor.constraint(equalTo: container.topAnchor, constant: LayoutConstants.previewInsets),
            pv.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -LayoutConstants.previewInsets),
            pv.trailingAnchor.constraint(equalTo: nextBtn.leadingAnchor, constant: -LayoutConstants.previewSpacing),

            nextBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            nextBtn.topAnchor.constraint(equalTo: container.topAnchor),
            nextBtn.bottomAnchor.constraint(equalTo: separator.topAnchor),
            nextBtn.widthAnchor.constraint(equalToConstant: aw),

            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: stack.topAnchor, constant: -LayoutConstants.separatorToStackSpacing),

            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -LayoutConstants.stackBottomInset),
            stack.heightAnchor.constraint(equalToConstant: LayoutConstants.stackHeight),
        ])

        p.contentView = container
        p.backgroundColor = warmBg
        p.center()
        p.makeFirstResponder(tv)

        // wire notifications
        NotificationCenter.default.addObserver(forName: .init("MediaInfoCopyAll"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.copyAllAction() }
        }
        NotificationCenter.default.addObserver(forName: .init("MediaInfoPrev"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.prevMedia() }
        }
        NotificationCenter.default.addObserver(forName: .init("MediaInfoNext"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.nextMedia() }
        }

        self.panel = p
        self.textView = tv
        self.imageView = iv
        self.playerView = pv
    }

    // MARK: - makeArrowButton — arrowshape, blue outline, with shadow
    func makeArrowButton(symbolName: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: .zero)
        btn.bezelStyle = .inline
        btn.isBordered = false
        let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        btn.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        btn.contentTintColor = .systemBlue
        btn.imageScaling = .scaleProportionallyDown
        btn.target = self
        btn.action = action
        btn.wantsLayer = true
        btn.layer?.backgroundColor = .clear
        btn.shadow = NSShadow()
        btn.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.35)
        btn.shadow?.shadowOffset = NSSize(width: 0.5, height: -1)
        btn.shadow?.shadowBlurRadius = 2
        return btn
    }
}
