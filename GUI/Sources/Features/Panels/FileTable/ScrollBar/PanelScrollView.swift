// PanelScrollView.swift
// MiMiNavigator
//
// Description: Shared scroll container for file table, thumbnail grid, and tree.

import AppKit
import SwiftUI

// MARK: - Panel Scroll View
struct PanelScrollView<Content: View>: View {
    let hasScrollableContent: Bool
    let onCapture: (NSScrollView?) -> Void
    private let content: Content

    init(
        hasScrollableContent: Bool,
        onCapture: @escaping (NSScrollView?) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.hasScrollableContent = hasScrollableContent
        self.onCapture = onCapture
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FileTableScrollViewCapture(hasScrollableContent: hasScrollableContent) { scrollView in
                    if let scrollView { ScrollBarSetup.apply(to: scrollView, hasScrollableContent: hasScrollableContent) }
                    onCapture(scrollView)
                }
                .frame(width: 0, height: 0)
                content
            }
        }
    }
}
