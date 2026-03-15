// HIGAutoFocusTextField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Forces AppKit first responder to the first editable NSTextField
//              inside a SwiftUI overlay dialog.

import AppKit
import SwiftUI

// MARK: - HIGAutoFocusTextField
struct HIGAutoFocusTextField: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            Task { @MainActor in
                guard let window = NSApp.keyWindow else { return }
                Self.focusFirstTextField(in: window.contentView)
            }
        }
    }
    private static func focusFirstTextField(in view: NSView?) {
        guard let view else { return }
        if let tf = view as? NSTextField, tf.isEditable {
            tf.window?.makeFirstResponder(tf)
            tf.selectText(nil)
            return
        }
        for sub in view.subviews {
            focusFirstTextField(in: sub)
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
