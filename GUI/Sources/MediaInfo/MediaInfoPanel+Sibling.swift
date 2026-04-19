//
//  MediaInfoPanel+Sibling.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import AVFoundation
import SwiftyBeaver
import UniformTypeIdentifiers

@MainActor
extension MediaInfoPanel {
    func loadMediaSiblings(for url: URL) {
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

    func navigateToMedia(at index: Int) {
        guard index >= 0, index < mediaFiles.count else { return }
        currentIndex = index
        let url = mediaFiles[index]
        currentURL = url
        configureConversionState(for: url)
        updatePreview(for: url)
        let getter = MediaInfoGetter()
        getter.getMediaInfoToFile(
            url: url,
            panelSide: currentPanelSide,
            appState: appState
        )
    }

    @objc func prevMedia() {
        guard currentIndex > 0 else { return }
        navigateToMedia(at: currentIndex - 1)
    }

    @objc func nextMedia() {
        guard currentIndex < mediaFiles.count - 1 else { return }
        navigateToMedia(at: currentIndex + 1)
    }

    func updatePreview(for url: URL) {
        let ext = url.pathExtension.lowercased()
        stopVideoPlayback()
        if Self.supportedImageExtensions.contains(ext), let img = NSImage(contentsOf: url) {
            showImagePreview(img)
            return
        }
        if Self.supportedVideoExtensions.contains(ext) {
            showVideoPreview(for: url)
            return
        }
        showImagePreview(fallbackIcon(for: url))
    }

    func showImagePreview(_ image: NSImage) {
        previewMode = .image
        previewImage = image
        currentVideoURL = nil
        player?.pause()
        playerView?.player = nil
        player = nil
    }

    func showVideoPreview(for url: URL) {
        previewMode = .video
        previewImage = nil
        currentVideoURL = url
        showCurrentVideoPreviewIfPossible()
    }

    func showCurrentVideoPreviewIfPossible() {
        guard previewMode == .video, let url = currentVideoURL, let playerView else { return }
        if let currentAsset = (player?.currentItem?.asset as? AVURLAsset)?.url, currentAsset == url {
            playerView.player = player
            return
        }

        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        player.pause()
        player.seek(to: .zero)
        playerView.player = player
        self.player = player
    }

    func stopVideoPlayback() {
        player?.pause()
        playerView?.player = nil
        player = nil
    }

    func fallbackIcon(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = PreviewConstants.iconSize
        return icon
    }
}
