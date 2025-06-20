//
//  BlurView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//


import SwiftUI

struct BlurView: NSViewRepresentable {
    @Binding var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.material = material
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material {
            nsView.material = material
            log.info("Material updated: \(material.rawValue)")
        }
    }
}
