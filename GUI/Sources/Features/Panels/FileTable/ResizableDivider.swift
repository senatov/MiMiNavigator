// ResizableDivider.swift
// MiMiNavigator — SwiftUI wrapper for NSResizableDividerView.
// Drag right → column to the left grows (Finder-style).

import AppKit
import SwiftUI

// MARK: - Resizable Divider
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    let onEnd: () -> Void
    var color: Color = ColorThemeStore.shared.activeTheme.columnDividerColor
    var onAutoFit: (() -> CGFloat)? = nil

    var body: some View {
        Representable(
            width: $width,
            min: min,
            max: max,
            color: color,
            onEnd: onEnd,
            onAutoFit: onAutoFit
        )
        .frame(width: 14)
    }
}

// MARK: - NSViewRepresentable

private struct Representable: NSViewRepresentable {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    let color: Color
    let onEnd: () -> Void
    var onAutoFit: (() -> CGFloat)?

    func makeNSView(context _: Context) -> NSResizableDividerView {
        let view = NSResizableDividerView()
        configure(view)
        return view
    }

    func updateNSView(_ view: NSResizableDividerView, context _: Context) {
        configure(view)
    }

    private func configure(_ view: NSResizableDividerView) {
        view.dividerColor = NSColor(color)
        view.onDrag = { delta in
            let newWidth = (width + delta).clamped(to: min ... max)
            width = newWidth
        }
        view.onDragEnd = onEnd
        view.onDoubleClick = {
            guard let fit = onAutoFit else { return }
            width = fit().clamped(to: min ... max)
            onEnd()
        }
    }
}

// MARK: - CGFloat Extension

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
