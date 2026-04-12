//
//  MediaInfoPanel+Sibling.swift
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
    // MARK: - Media siblings
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

    // MARK: - navigateToMedia (NO window move/resize)
    func navigateToMedia(at index: Int) {
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

    @objc func prevMedia() {
        guard currentIndex > 0 else { return }
        navigateToMedia(at: currentIndex - 1)
    }

    @objc func nextMedia() {
        guard currentIndex < mediaFiles.count - 1 else { return }
        navigateToMedia(at: currentIndex + 1)
    }

    // MARK: - updatePreview (images + video thumbnails via AVAssetImageGenerator)
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
        imageView?.image = image
        imageView?.isHidden = false
        player?.stop()
        player?.drawable = nil
        playerView?.isHidden = true
        player = nil
    }

    func showVideoPreview(for url: URL) {
        guard let playerView else {
            showImagePreview(fallbackIcon(for: url))
            return
        }
        let media = VLCMedia(url: url)
        let mediaPlayer = VLCMediaPlayer()
        mediaPlayer.media = media
        mediaPlayer.drawable = playerView
        mediaPlayer.delegate = self
        self.player = mediaPlayer
        imageView?.isHidden = true
        playerView.isHidden = false
        mediaPlayer.play()
    }

    func stopVideoPlayback() {
        player?.stop()
        player?.drawable = nil
        playerView?.isHidden = true
        player = nil
    }

    func fallbackIcon(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = PreviewConstants.iconSize
        return icon
    }
}
