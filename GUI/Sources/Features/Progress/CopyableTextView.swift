// CopyableTextView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Read-only text view that keeps Command-C working in ProgressPanel.

import AppKit

// MARK: - CopyableTextView

final class CopyableTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }

    // MARK: - Configure
    func configureForProgressLog(insets: NSSize, linePadding: CGFloat) {
        isEditable = false
        isAutomaticTextCompletionEnabled = false
        allowsUndo = true
        isRichText = false
        drawsBackground = false
        textContainerInset = insets
        textContainer?.lineFragmentPadding = linePadding
        textContainer?.widthTracksTextView = true
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if let textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: max(bounds.width - insets.width * 2, 1), height: .greatestFiniteMagnitude)
        }
    }

    // MARK: - Keep Log Text Within Its Window
    override func layout() {
        super.layout()
        guard let textContainer, bounds.width > 0 else { return }
        let availableWidth = max(bounds.width - textContainerInset.width * 2, 1)
        guard abs(textContainer.containerSize.width - availableWidth) > 0.5 else { return }
        textContainer.containerSize = NSSize(width: availableWidth, height: .greatestFiniteMagnitude)
    }

    // MARK: - Perform Key Equivalent
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            copy(self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
