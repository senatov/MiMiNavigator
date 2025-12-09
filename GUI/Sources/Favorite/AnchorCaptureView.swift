//
// AnchorCaptureView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - AnchorCaptureView (captures NSView for precise popover positioning)
struct AnchorCaptureView: NSViewRepresentable {
    let onResolve: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        // Defer to next runloop so hierarchy is ready
        Task { @MainActor in
            onResolve(v)
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Keep reporting the same view (no-op)
    }
}
