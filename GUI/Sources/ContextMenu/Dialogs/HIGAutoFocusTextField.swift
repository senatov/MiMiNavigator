// HIGAutoFocusTextField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Forces AppKit first responder to the first editable NSTextField
//              inside a SwiftUI overlay dialog.

import AppKit
import Dispatch
import SwiftUI

// MARK: - HIGAutoFocusTextField
struct HIGAutoFocusTextField: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            Self.scheduleInitialFocus()
        }
    }
    private static func focusFirstTextField(in view: NSView?) {
        guard let textField = firstEditableTextField(in: view) else { return }
        focus(textField)
    }

    private static func scheduleInitialFocus() {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow else { return }
            focusFirstTextField(in: window.contentView)
        }
    }

    private static func firstEditableTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let textField = view as? NSTextField, textField.isEditable {
            return textField
        }

        for subview in view.subviews {
            if let textField = firstEditableTextField(in: subview) {
                return textField
            }
        }

        return nil
    }

    private static func focus(_ textField: NSTextField) {
        DispatchQueue.main.async {
            guard let window = textField.window else { return }
            window.makeFirstResponder(textField)
            textField.selectText(nil)
        }
    }
}

// MARK: - View Extension
extension View {
    /// Apply to any dialog that contains a HIGTextField to auto-focus it on appear.
    func higAutoFocusTextField() -> some View {
        modifier(HIGAutoFocusTextField())
    }
}
