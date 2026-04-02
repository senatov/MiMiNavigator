// HIGAutoFocusTextField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Forces AppKit first responder to the first editable NSTextField
//              inside a SwiftUI overlay dialog.
//              Uses Task @MainActor to avoid QoS priority inversion warnings.

import AppKit
import SwiftUI

// MARK: - HIGAutoFocusTextField

struct HIGAutoFocusTextField: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            // single MainActor hop — avoids priority inversion between
            // User-interactive (SwiftUI render) and Default (DispatchQueue.main)
            Task { @MainActor in
                // tiny yield so the SwiftUI layout pass finishes first
                try? await Task.sleep(for: .milliseconds(50))
                guard let window = NSApp.keyWindow else { return }
                guard let textField = Self.firstEditableTextField(in: window.contentView) else { return }
                window.makeFirstResponder(textField)
                textField.selectText(nil)
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
}


// MARK: - View Extension

extension View {
    /// Apply to any dialog that contains a HIGTextField to auto-focus it on appear.
    func higAutoFocusTextField() -> some View {
        modifier(HIGAutoFocusTextField())
    }
}
