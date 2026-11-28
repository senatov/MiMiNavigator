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
    var gripWidth = ColumnAutoFitMetrics.dividerWidth

    var body: some View {
        Representable(
            width: $width,
            min: min,
            max: max,
            color: color,
            onEnd: onEnd,
            onAutoFit: onAutoFit
        )
        .frame(width: gripWidth)
        .overlay {
            Rectangle()
                .fill(color)
                .frame(width: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - NSViewRepresentable

private struct Representable: NSViewRepresentable {
    // MARK: - Drag State
    final class Coordinator {
        var initialWidth: CGFloat = 0
    }

    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    let color: Color
    let onEnd: () -> Void
    var onAutoFit: (() -> CGFloat)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSResizableDividerView {
        let view = NSResizableDividerView()
        configure(view, drag: context.coordinator)
        return view
    }

    func updateNSView(_ view: NSResizableDividerView, context: Context) {
        configure(view, drag: context.coordinator)
    }

    private func configure(_ view: NSResizableDividerView, drag: Coordinator) {
        view.dividerColor = NSColor(color)
        view.onDragStart = { drag.initialWidth = width }
        view.onDrag = { delta in
            let newWidth = (drag.initialWidth + delta).clamped(to: min ... max)
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
