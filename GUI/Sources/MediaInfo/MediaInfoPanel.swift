//
//  MediaInfoPanel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit

final class MediaTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            if self.selectedRange().length == 0 {
                NotificationCenter.default.post(name: .init("MediaInfoCopyAll"), object: nil)
                return
            }
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 123 { // left arrow
            NotificationCenter.default.post(name: .init("MediaInfoPrev"), object: nil)
            return true
        }
        if event.keyCode == 124 { // right arrow
            NotificationCenter.default.post(name: .init("MediaInfoNext"), object: nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class MediaInfoPanel {

    static let shared = MediaInfoPanel()

    private var panel: NSPanel?
    private var textView: NSTextView?
    private var currentURL: URL?
    private var currentCoordinates: (Double, Double)?

    // MARK: - Public API

    func show(title: String, text: String, url: URL? = nil, coordinates: (Double, Double)? = nil) {
        if panel == nil {
            createPanel()
        }

        panel?.title = title
        currentURL = url
        currentCoordinates = coordinates ?? extractCoordinates(from: text)

        let attributed = buildAttributedContent(baseText: text, coordinates: currentCoordinates)
        textView?.textStorage?.setAttributedString(attributed)
        textView?.scrollToBeginningOfDocument(nil)

        panel?.makeKeyAndOrderFront(nil)
        panel?.makeKey()
    }

    func update(title: String, text: String) {
        show(title: title, text: text, coordinates: nil)
    }

    func update(title: String, text: String, coordinates: (Double, Double)?) {
        show(title: title, text: text, coordinates: coordinates)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Private

    private func createPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 300, y: 300, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
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

        let scrollView = NSScrollView(frame: p.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.92, alpha: 1.0)

        let tv = MediaTextView(frame: scrollView.bounds)
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = true
        tv.importsGraphics = false
        tv.usesFindPanel = true
        tv.allowsUndo = true
        tv.isAutomaticLinkDetectionEnabled = false
        tv.linkTextAttributes = [
            .foregroundColor: NSColor(calibratedRed: 0.0, green: 0.2, blue: 0.5, alpha: 1.0),
            .cursor: NSCursor.pointingHand
        ]
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = NSColor.labelColor
        tv.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.92, alpha: 1.0)
        tv.textContainerInset = NSSize(width: 12, height: 12)

        // Context menu
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "")
        tv.menu = menu

        scrollView.documentView = tv

        // Buttons
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeAction))
        let revealButton = NSButton(title: "Reveal", target: self, action: #selector(revealAction))
        let copyButton = NSButton(title: "Copy All", target: self, action: #selector(copyAllAction))
        let copyPathButton = NSButton(title: "Copy Path", target: self, action: #selector(copyPathAction))

        [closeButton, revealButton, copyButton, copyPathButton].forEach {
            $0.bezelStyle = .rounded
        }

        // Tooltips
        copyPathButton.toolTip = "Copy file path"
        copyButton.toolTip = "Copy full info"
        revealButton.toolTip = "Reveal in Finder"
        closeButton.toolTip = "Close panel"

        let stack = NSStackView(views: [copyPathButton, copyButton, revealButton, closeButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stack.distribution = .gravityAreas
        stack.setHuggingPriority(.required, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Keyboard Shortcuts
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = [.command, .shift]

        copyPathButton.keyEquivalent = "c"
        copyPathButton.keyEquivalentModifierMask = [.command, .option]

        revealButton.keyEquivalent = "r"
        revealButton.keyEquivalentModifierMask = [.command]

        let container = NSView(frame: p.contentView!.bounds)
        container.autoresizingMask = [.width, .height]

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(scrollView)
        container.addSubview(separator)
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            // Separator
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: stack.topAnchor, constant: -6),

            // Stack
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            stack.heightAnchor.constraint(equalToConstant: 28)
        ])

        p.contentView = container

        // Center relative to main window if available
        if let main = NSApp.mainWindow {
            p.setFrameOrigin(NSPoint(
                x: main.frame.midX - p.frame.width / 2,
                y: main.frame.midY - p.frame.height / 2
            ))
        } else {
            p.center()
        }
        p.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.92, alpha: 1.0)

        p.makeFirstResponder(tv)
        NotificationCenter.default.addObserver(forName: .init("MediaInfoCopyAll"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.copyAllAction()
            }
        }

        self.panel = p
        self.textView = tv
    }

    private func makeIconAttachment(systemName: String) -> NSAttributedString {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(config)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -2, width: 16, height: 16)

        let attachmentString = NSAttributedString(attachment: attachment)
        return attachmentString
    }

    private func buildAttributedContent(baseText: String, coordinates: (Double, Double)?) -> NSAttributedString {
        let bodyFont = NSFont.systemFont(ofSize: 12, weight: .light)
        let headerFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        let textColor = NSColor.labelColor

        let result = NSMutableAttributedString()

        let lines = baseText.components(separatedBy: "\n")

        var currentSection: String? = nil
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: textColor
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: textColor
        ]

        func appendHeader(_ title: String) {
            result.append(NSAttributedString(string: "\n\(title)\n", attributes: headerAttributes))
        }

        for line in lines {
            if line.hasPrefix("---") {
                currentSection = line.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
                appendHeader(currentSection ?? "")
                continue
            }
            result.append(NSAttributedString(string: line + "\n", attributes: bodyAttributes))
        }

        guard let (lat, lon) = coordinates else {
            return result
        }

        let googleURLString = "https://www.google.com/maps?q=\(lat),\(lon)"
        let appleURLString = "https://maps.apple.com/?ll=\(lat),\(lon)"
        let osmURLString = "https://www.openstreetmap.org/?mlat=\(lat)&mlon=\(lon)#map=15/\(lat)/\(lon)"
        let hereURLString = "https://wego.here.com/?map=\(lat),\(lon),15,normal"
        let bingURLString = "https://www.bing.com/maps?q=\(lat),\(lon)"
        let mapquestURLString = "https://www.mapquest.com/latlng/\(lat),\(lon)"
        let mapyczURLString = "https://mapy.cz/zakladni?x=\(lon)&y=\(lat)&z=15"
        let baiduURLString = "https://api.map.baidu.com/marker?location=\(lat),\(lon)&output=html&lang=en"

        result.append(NSAttributedString(string: "\nMaps\n", attributes: headerAttributes))
        appendMapLink(into: result, icon: "globe", title: "Google", urlString: googleURLString)
        appendMapLink(into: result, icon: "applelogo", title: "Apple", urlString: appleURLString)
        appendMapLink(into: result, icon: "map", title: "OpenStreetMap", urlString: osmURLString)
        appendMapLink(into: result, icon: "location.circle", title: "HERE", urlString: hereURLString)
        appendMapLink(into: result, icon: "network", title: "Bing", urlString: bingURLString)
        appendMapLink(into: result, icon: "map", title: "MapQuest", urlString: mapquestURLString)
        appendMapLink(into: result, icon: "map", title: "Mapy.cz", urlString: mapyczURLString)
        appendMapLink(into: result, icon: "globe.asia.australia", title: "Baidu", urlString: baiduURLString)

        return result
    }

    private func appendMapLink(
        into result: NSMutableAttributedString,
        icon: String,
        title: String,
        urlString: String
    ) {
        guard let url = URL(string: urlString) else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 4

        let line = NSMutableAttributedString()

        line.append(makeIconAttachment(systemName: icon))
        line.append(NSAttributedString(string: "   "))

        let label = NSAttributedString(
            string: title + "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.linkColor,
                .link: url,
                .paragraphStyle: paragraphStyle
            ]
        )

        line.append(label)
        result.append(line)
    }

    private func extractCoordinates(from text: String) -> (Double, Double)? {

        // Try Apple Maps style (ll=lat,lon)
        if let llRange = text.range(of: "ll=") {
            let tail = text[llRange.upperBound..<text.endIndex]
            let coordsPart = String(tail.split(whereSeparator: { $0 == "\n" || $0 == "&" }).first ?? "")
            let coords = coordsPart.split(separator: ",")

            if coords.count == 2,
               let lat = Double(String(coords[0]).trimmingCharacters(in: .whitespaces)),
               let lon = Double(String(coords[1]).trimmingCharacters(in: .whitespaces)) {
                return (lat, lon)
            }
        }

        // Try GPS line
        if let gpsRange = text.range(of: "GPS:") {
            let substring = text[gpsRange.lowerBound..<text.endIndex]
            let line = String(substring.split(separator: "\n").first ?? "")
            let numbers = line.split(whereSeparator: { !$0.isNumber && $0 != "." && $0 != "-" })

            if numbers.count >= 2,
               let lat = Double(String(numbers[0]).trimmingCharacters(in: .whitespaces)),
               let lon = Double(String(numbers[1]).trimmingCharacters(in: .whitespaces)) {
                return (lat, lon)
            }
        }

        return nil
    }

    @objc private func copyPathAction() {
        guard let url = currentURL else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.path, forType: .string)
    }

    @objc private func copyAllAction() {
        guard let text = textView?.string else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc private func revealAction() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func closeAction() {
        hide()
    }
}
