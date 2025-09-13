//
//  BlurView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct BlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        log.info(#function + " Creating default NSVisualEffectView")
        return NSVisualEffectView()
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        log.info(#function + " Default update — nothing changed")
    }
}

