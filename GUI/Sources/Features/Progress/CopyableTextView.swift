// CopyableTextView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Read-only text view that keeps Command-C working in ProgressPanel.

import AppKit

// MARK: - CopyableTextView

final class CopyableTextView: NSTextView {
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
