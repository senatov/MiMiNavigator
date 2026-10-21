// FileTableScrollViewCapture.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Captures the native NSScrollView backing the SwiftUI file table.

import AppKit
import SwiftUI

// MARK: - File Table Scroll View Capture
struct FileTableScrollViewCapture: NSViewRepresentable {
    let hasScrollableContent: Bool
    let onCapture: (NSScrollView?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.update(hasScrollableContent: hasScrollableContent, onCapture: onCapture)
        context.coordinator.capture(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(hasScrollableContent: hasScrollableContent, onCapture: onCapture)
        context.coordinator.capture(from: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    // MARK: - Coordinator
    @MainActor
    final class Coordinator {
        private var onCapture: (NSScrollView?) -> Void
        private var hasScrollableContent = false
        private weak var capturedScrollView: NSScrollView?
        private var capturedScrollableContent: Bool?
        private var capturedScrollerStyle: NSScroller.Style?
        private var captureScheduled = false

        init(onCapture: @escaping (NSScrollView?) -> Void) {
            self.onCapture = onCapture
        }

        func update(hasScrollableContent: Bool, onCapture: @escaping (NSScrollView?) -> Void) {
            self.hasScrollableContent = hasScrollableContent
            self.onCapture = onCapture
        }

        func capture(from view: NSView) {
            guard !captureScheduled else { return }
            captureScheduled = true
            Task { @MainActor [weak self, weak view] in
                guard let self else { return }
                self.captureScheduled = false
                guard let view else { return }
                let scrollView = Self.enclosingScrollView(from: view)
                let scrollerStyle = NSScroller.preferredScrollerStyle
                guard scrollView !== self.capturedScrollView
                    || self.capturedScrollableContent != self.hasScrollableContent
                    || self.capturedScrollerStyle != scrollerStyle else { return }
                self.capturedScrollView = scrollView
                self.capturedScrollableContent = self.hasScrollableContent
                self.capturedScrollerStyle = scrollerStyle
                self.onCapture(scrollView)
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
