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
        log.info(#function)
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.material = .sidebar
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        log.info(#function)
    }
}
