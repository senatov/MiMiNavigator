//
//  MediaInfoVideoPreview.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AVKit
import AppKit
import SwiftUI

@MainActor
struct MediaInfoVideoPreview: NSViewRepresentable {
    @ObservedObject var controller: MediaInfoPanel

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .default
        view.showsFrameSteppingButtons = true
        view.updatesNowPlayingInfoCenter = false
        controller.playerView = view
        controller.showCurrentVideoPreviewIfPossible()
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        controller.playerView = nsView
        controller.showCurrentVideoPreviewIfPossible()
    }
}
