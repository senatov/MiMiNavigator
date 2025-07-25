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
        if nsView.material != material {
            nsView.material = material
            log.info("Material updated: \(material.rawValue)")
        }
    }

    // MARK: -
    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick)
    }

    // MARK: -
    class Coordinator: NSObject {
        let onClick: (() -> Void)?

        init(onClick: (() -> Void)?) {
            self.onClick = onClick
        }

        @objc func handleClick() {
            log.debug("BlurView clicked")
            onClick?()
        }
    }
}
