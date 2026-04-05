//
//  MediaInfoPanel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Descr: media info floating panel — info + preview + prev/next navigation

import AVFoundation
import AppKit
import SwiftyBeaver
import UniformTypeIdentifiers

// MARK: - MediaInfoPanel
@MainActor
final class MediaInfoPanel {

    private let log = SwiftyBeaver.self

    static let shared = MediaInfoPanel()

    private var panel: NSPanel?
    private var textView: NSTextView?
    private var imageView: NSImageView?
    private var currentURL: URL?
    private var currentCoordinates: (Double, Double)?
    private var mediaFiles: [URL] = []
    private var currentIndex: Int = 0
    private var panelCreated = false

    private enum PreviewConstants {
        static let iconSize = NSSize(width: 128, height: 128)
        static let thumbnailMaxSize = CGSize(width: 480, height: 480)
        static let thumbnailTime = CMTime(seconds: 1, preferredTimescale: 600)
    }

    private enum LayoutConstants {
        static let panelSize = NSSize(width: 900, height: 550)
        static let minPanelSize = NSSize(width: 600, height: 350)
        static let arrowWidth: CGFloat = 32
        static let previewInsets: CGFloat = 8
        static let previewSpacing: CGFloat = 4
        static let stackBottomInset: CGFloat = 8
        static let separatorToStackSpacing: CGFloat = 6
        static let stackHeight: CGFloat = 28
        static let textWidthMultiplier: CGFloat = 0.48
    }

    private static let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "ico", "svg",
    ]
    private static let supportedVideoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "ts", "webm"]
    private static let supportedAudioExtensions: Set<String> = ["mp3", "aac", "flac", "wav", "m4a", "ogg", "wma", "aiff", "alac"]
    private static let supportedMediaExtensions: Set<String> =
        supportedImageExtensions
        .union(supportedVideoExtensions)
        .union(supportedAudioExtensions)

    // MARK: - show (first open only positions window)
    func show(title: String, text: String, url: URL? = nil, coordinates: (Double, Double)? = nil) {
        log.debug(#function)
        ensurePanelExists()
        currentURL = url
        currentCoordinates = coordinates ?? extractCoordinates(from: text)

        if let url {
            loadMediaSiblings(for: url)
            updatePreview(for: url)
        }
        log.debug("[MediaInfoPanel] show url=\(url?.path ?? "nil")")
        refreshText(title: title, text: text)
        positionPanelIfNeeded()
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeKey()
    }

    // MARK: - update (content only — never move/resize)
    func update(title: String, text: String) {
        update(title: title, text: text, coordinates: nil)
    }

    func update(title: String, text: String, coordinates: (Double, Double)?) {
        log.debug("[MediaInfoPanel] update title=\(title)")
        currentCoordinates = coordinates ?? extractCoordinates(from: text)
        refreshText(title: title, text: text)
    }

    func hide() { panel?.orderOut(nil) }

    private func ensurePanelExists() {
        if panel == nil {
            createPanel()
        }
    }

    private func positionPanelIfNeeded() {
        guard !panelCreated, let panel else { return }
        panelCreated = true

        if let main = NSApp.mainWindow {
            panel.setFrameOrigin(
                NSPoint(
                    x: main.frame.midX - panel.frame.width / 2,
                    y: main.frame.midY - panel.frame.height / 2
                ))
        }
    }

    // MARK: - refreshText (internal — just update text content)
    private func refreshText(title: String, text: String) {
        panel?.title = title
        let attr = buildAttributedContent(baseText: text, coordinates: currentCoordinates)
        textView?.textStorage?.setAttributedString(attr)
        textView?.scrollToBeginningOfDocument(nil)
    }

    // MARK: - Media siblings
    private func loadMediaSiblings(for url: URL) {
        let dir = url.deletingLastPathComponent()

        do {
            let items = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            mediaFiles =
                items
                .filter { Self.supportedMediaExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            currentIndex = mediaFiles.firstIndex(of: url) ?? 0
        } catch {
            mediaFiles = [url]
            currentIndex = 0
            log.error("[MediaInfoPanel] Failed to load siblings for \(url.path): \(error.localizedDescription)")
        }
    }

    // MARK: - navigateToMedia (NO window move/resize)
    private func navigateToMedia(at index: Int) {
        guard index >= 0, index < mediaFiles.count else { return }
        currentIndex = index
        let url = mediaFiles[index]
        currentURL = url
        updatePreview(for: url)
        panel?.title = "📦 \(url.lastPathComponent)"
        // only update text — getMediaInfoToFile calls update(), not show()
        Task(priority: .userInitiated) {
            let getter = MediaInfoGetter()
            getter.getMediaInfoToFile(url: url)
        }
    }

    @objc private func prevMedia() {
        guard currentIndex > 0 else { return }
        navigateToMedia(at: currentIndex - 1)
    }

    @objc private func nextMedia() {
        guard currentIndex < mediaFiles.count - 1 else { return }
        navigateToMedia(at: currentIndex + 1)
    }

    // MARK: - updatePreview (images + video thumbnails via AVAssetImageGenerator)
    private func updatePreview(for url: URL) {
        guard let imageView else { return }

        let ext = url.pathExtension.lowercased()

        if Self.supportedImageExtensions.contains(ext), let img = NSImage(contentsOf: url) {
            applyPreviewImage(img, to: imageView)
            return
        }

        if Self.supportedVideoExtensions.contains(ext) {
            updateVideoPreview(for: url)
            return
        }

        applyPreviewImage(fallbackIcon(for: url), to: imageView)
    }

    private func updateVideoPreview(for url: URL) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let thumb = await Self.videoThumbnail(url: url)
            await MainActor.run {
                guard self.currentURL == url else { return }
                if let imageView = self.imageView {
                    self.applyPreviewImage(thumb, to: imageView)
                }
            }
        }
    }

    private func applyPreviewImage(_ image: NSImage, to imageView: NSImageView) {
        imageView.image = image
        imageView.isHidden = false
    }

    private func fallbackIcon(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = PreviewConstants.iconSize
        return icon
    }

    // MARK: - videoThumbnail
    private nonisolated static func videoThumbnail(url: URL) async -> NSImage {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = PreviewConstants.thumbnailMaxSize
        let time = PreviewConstants.thumbnailTime

        do {
            let cgImg = try await generateThumbnailImage(generator: gen, time: time)
            return NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
        } catch {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = PreviewConstants.iconSize
            return icon
        }
    }

    private nonisolated static func generateThumbnailImage(generator: AVAssetImageGenerator, time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(
                        throwing: error
                            ?? NSError(
                                domain: "MediaInfoPanel",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "AVAssetImageGenerator returned no image"]
                            ))
                }
            }
        }
    }

    // MARK: - createPanel
    private func createPanel() {
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
    }

    // MARK: - makeArrowButton — arrowshape, blue outline, with shadow
    private func makeArrowButton(symbolName: String, action: Selector) -> NSButton {
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

    // MARK: - makeIconAttachment
    private func makeIconAttachment(systemName: String) -> NSAttributedString {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        let att = NSTextAttachment()
        att.image = image
        att.bounds = NSRect(x: 0, y: -2, width: 16, height: 16)
        return NSAttributedString(attachment: att)
    }

    // MARK: - buildAttributedContent
    private func buildAttributedContent(baseText: String, coordinates: (Double, Double)?) -> NSAttributedString {
        let bodyFont = NSFont.systemFont(ofSize: 12, weight: .light)
        let headerFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        let color = NSColor.labelColor
        let result = NSMutableAttributedString()
        let headerA: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: color]
        let bodyA: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: color]
        for line in baseText.components(separatedBy: "\n") {
            if line.hasPrefix("---") {
                let s = line.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
                result.append(NSAttributedString(string: "\n\(s)\n", attributes: headerA))
            } else {
                result.append(NSAttributedString(string: line + "\n", attributes: bodyA))
            }
        }
        guard let (lat, lon) = coordinates else { return result }
        result.append(NSAttributedString(string: "\nMaps\n", attributes: headerA))
        appendMapLink(into: result, icon: "globe", title: "Google", urlString: "https://www.google.com/maps?q=\(lat),\(lon)")
        appendMapLink(into: result, icon: "applelogo", title: "Apple", urlString: "https://maps.apple.com/?ll=\(lat),\(lon)")
        appendMapLink(
            into: result, icon: "map", title: "OSM",
            urlString: "https://www.openstreetmap.org/?mlat=\(lat)&mlon=\(lon)#map=15/\(lat)/\(lon)")
        appendMapLink(
            into: result, icon: "location.circle", title: "HERE", urlString: "https://wego.here.com/?map=\(lat),\(lon),15,normal")
        return result
    }

    private func appendMapLink(into result: NSMutableAttributedString, icon: String, title: String, urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4
        ps.paragraphSpacing = 4
        let line = NSMutableAttributedString()
        line.append(makeIconAttachment(systemName: icon))
        line.append(NSAttributedString(string: "   "))
        line.append(
            NSAttributedString(
                string: title + "\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .light),
                    .foregroundColor: NSColor.linkColor, .link: url, .paragraphStyle: ps,
                ]))
        result.append(line)
    }

    private func extractCoordinates(from text: String) -> (Double, Double)? {
        if let r = text.range(of: "ll=") {
            let t = text[r.upperBound...]
            let p = String(t.split(whereSeparator: { $0 == "\n" || $0 == "&" }).first ?? "")
            let c = p.split(separator: ",")
            if c.count == 2, let la = Double(c[0].trimmingCharacters(in: .whitespaces)),
                let lo = Double(c[1].trimmingCharacters(in: .whitespaces))
            {
                return (la, lo)
            }
        }
        if let r = text.range(of: "GPS:") {
            let ln = String(text[r.lowerBound...].split(separator: "\n").first ?? "")
            let n = ln.split(whereSeparator: { !$0.isNumber && $0 != "." && $0 != "-" })
            if n.count >= 2, let la = Double(n[0].trimmingCharacters(in: .whitespaces)),
                let lo = Double(n[1].trimmingCharacters(in: .whitespaces))
            {
                return (la, lo)
            }
        }
        return nil
    }

    // MARK: - Actions
    @objc private func copyPathAction() {
        guard let url = currentURL else { return }
        copyToPasteboard(url.path)
    }

    @objc private func copyAllAction() {
        guard let text = textView?.string else { return }
        copyToPasteboard(text)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    @objc private func revealAction() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func closeAction() { hide() }
}
