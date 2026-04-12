//
//  MediaInfoPanel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Descr: media info floating panel — info + preview + prev/next navigation

import AppKit
import SwiftyBeaver
import UniformTypeIdentifiers
@preconcurrency import VLC

// MARK: - MediaInfoPanel
@MainActor
final class MediaInfoPanel: NSObject {

    private let log = SwiftyBeaver.self

    static let shared = MediaInfoPanel()

    var panel: NSPanel?
    var textView: NSTextView?
    var imageView: NSImageView?
    var playerView: VLCVideoView?
    var player: VLCMediaPlayer?

    var currentURL: URL?
    var currentCoordinates: (Double, Double)?
    var mediaFiles: [URL] = []
    var currentIndex = 0
    var panelCreated = false

    private override init() {
        super.init()
    }

    enum PreviewConstants {
        static let iconSize = NSSize(width: 128, height: 128)
    }

    enum LayoutConstants {
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

    static let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "ico", "svg",
    ]
    static let supportedVideoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "ts", "webm"]
    static let supportedAudioExtensions: Set<String> = ["mp3", "aac", "flac", "wav", "m4a", "ogg", "wma", "aiff", "alac"]
    static let supportedMediaExtensions: Set<String> =
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

    func hide() {
        stopVideoPlayback()
        panel?.orderOut(nil)
    }

    func ensurePanelExists() {
        if panel == nil {
            createPanel()
        }
    }

    func positionPanelIfNeeded() {
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
    func refreshText(title: String, text: String) {
        panel?.title = title
        let attr = buildAttributedContent(baseText: text, coordinates: currentCoordinates)
        textView?.textStorage?.setAttributedString(attr)
        textView?.scrollToBeginningOfDocument(nil)
    }
}


extension MediaInfoPanel: @preconcurrency VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification!) {
        Task { @MainActor [weak self] in
            guard let self, let player = self.player else { return }
            switch player.state {
            case .error:
                guard let url = self.currentURL else { return }
                self.log.error("[MediaInfoPanel] VLC player failed for \(url.path)")
                self.stopVideoPlayback()
                self.showImagePreview(self.fallbackIcon(for: url))
            default:
                break
            }
        }
    }
}
