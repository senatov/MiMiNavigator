// HIGAutoFocusTextField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Forces AppKit first responder to the first editable NSTextField
//              inside a SwiftUI overlay dialog. Falls back to rightmost button
//              if no text field found. Retries up to 3 times with increasing delay.

import AppKit
import SwiftUI

// MARK: - HIGAutoFocusTextField

struct HIGAutoFocusTextField: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            Self.scheduleFocusAttempt(attempt: 1)
        }
    }


    private static func firstEditableTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let textField = view as? NSTextField, textField.isEditable {
            return textField
        }
        for subview in view.subviews {
            if let found = firstEditableTextField(in: subview) {
                return found
            }
        }
        return nil
    }


    private static func rightmostButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        var buttons: [NSButton] = []
        collectButtons(in: view, into: &buttons)
        return buttons.max(by: { $0.frame.origin.x < $1.frame.origin.x })
    }


    private static func collectButtons(in view: NSView, into buttons: inout [NSButton]) {
        if let button = view as? NSButton, button.isEnabled {
            buttons.append(button)
        }
        for subview in view.subviews {
            collectButtons(in: subview, into: &buttons)
        }
    }

    private static let maxAttempts = 3
    private static let retryDelayStep: TimeInterval = 0.08


    @MainActor
    private static func scheduleFocusAttempt(attempt: Int) {
        let delay = retryDelayStep * Double(attempt)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Self.performFocusAttempt(attempt: attempt)
        }
    }


    @MainActor
    private static func performFocusAttempt(attempt: Int) {
        guard let window = NSApp.keyWindow else {
            retryFocusIfNeeded(after: attempt)
            return
        }

        if let textField = firstEditableTextField(in: window.contentView) {
            focus(textField: textField, in: window, attempt: attempt)
            return
        }

        if attempt < maxAttempts {
            scheduleFocusAttempt(attempt: attempt + 1)
            return
        }

        focusFallbackButton(in: window)
    }


    @MainActor
    private static func retryFocusIfNeeded(after attempt: Int) {
        guard attempt < maxAttempts else { return }
        scheduleFocusAttempt(attempt: attempt + 1)
    }


    @MainActor
    private static func focus(textField: NSTextField, in window: NSWindow, attempt: Int) {
        let didFocus = window.makeFirstResponder(textField)
        guard didFocus else {
            log.debug("[HIGAutoFocus] failed to focus text field on attempt \(attempt)")
            retryFocusIfNeeded(after: attempt)
            return
        }

        textField.selectText(nil)
        log.debug("[HIGAutoFocus] focused text field on attempt \(attempt)")
    }


    @MainActor
    private static func focusFallbackButton(in window: NSWindow) {
        guard let button = rightmostButton(in: window.contentView) else {
            log.debug("[HIGAutoFocus] fallback failed: no enabled button found")
            return
        }

        let didFocus = window.makeFirstResponder(button)
        if didFocus {
            log.debug("[HIGAutoFocus] fallback: focused rightmost button")
        } else {
            log.debug("[HIGAutoFocus] fallback failed: could not focus rightmost button")
        }
    }
}


// MARK: - View Extension

extension View {
    /// Apply to any dialog that contains a HIGTextField to auto-focus it on appear.
    /// Falls back to focusing rightmost button if no text field exists.
    func higAutoFocusTextField() -> some View {
        modifier(HIGAutoFocusTextField())
    }
}
