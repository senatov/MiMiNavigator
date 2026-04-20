//
//  MediaInfoAnimatedImagePreview.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

@MainActor
struct MediaInfoAnimatedImagePreview: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.animates = true
        view.image = image
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.animates = true
        nsView.image = image
    }
}
