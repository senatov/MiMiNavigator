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
    var onClick: (() -> Void)? = nil

    // MARK: -
    func makeNSView(context: Context) -> NSVisualEffectView {
        log.info(#function +    "Creating NSVisualEffectView with material: \(material.rawValue)")
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.material = material
        view.state = .active
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick))
        view.addGestureRecognizer(clickGesture)

        return view
    }

    // MARK: -
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        log.info(#function + "Updating NSVisualEffectView with material: \(material.rawValue)")
        if nsView.material != material {
            nsView.material = material
            log.info("Material updated: \(material.rawValue)")
        }
    }

    // MARK: -
    func makeCoordinator() -> Coordinator {
        log.info(#function + "Creating Coordinator for BlurView")
        return Coordinator(onClick: onClick)
    }

}
