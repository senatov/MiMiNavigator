// FileTableScrollViewCapture.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Captures the native NSScrollView backing the SwiftUI file table.

import AppKit
import SwiftUI

// MARK: - File Table Scroll View Capture
struct FileTableScrollViewCapture: NSViewRepresentable {
    let onCapture: (NSScrollView?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.capture(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.capture(from: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    // MARK: - Coordinator
    @MainActor
    final class Coordinator {
        private let onCapture: (NSScrollView?) -> Void

        init(onCapture: @escaping (NSScrollView?) -> Void) {
            self.onCapture = onCapture
        }

        func capture(from view: NSView) {
            Task { @MainActor in
                self.onCapture(Self.enclosingScrollView(from: view))
            }
        }

        private static func enclosingScrollView(from view: NSView) -> NSScrollView? {
            var current = view.superview
            while let node = current {
                if let scrollView = node as? NSScrollView {
                    return scrollView
                }
                current = node.superview
            }
            return nil
        }
    }
}
