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
            Task { @MainActor in
                for attempt in 1...3 {
                    let delay = Duration.milliseconds(80 * attempt)
                    try? await Task.sleep(for: delay)
                    guard let window = NSApp.keyWindow else { continue }
                    if let textField = Self.firstEditableTextField(in: window.contentView) {
                        window.makeFirstResponder(textField)
                        textField.selectText(nil)
                        log.debug("[HIGAutoFocus] focused text field on attempt \(attempt)")
                        return
                    }
                }
                // fallback: focus rightmost button if no text field found
                if let window = NSApp.keyWindow,
                   let button = Self.rightmostButton(in: window.contentView) {
                    window.makeFirstResponder(button)
                    log.debug("[HIGAutoFocus] fallback: focused rightmost button")
                }
            }
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
}


// MARK: - View Extension

extension View {
    /// Apply to any dialog that contains a HIGTextField to auto-focus it on appear.
    /// Falls back to focusing rightmost button if no text field exists.
    func higAutoFocusTextField() -> some View {
        modifier(HIGAutoFocusTextField())
    }
}
