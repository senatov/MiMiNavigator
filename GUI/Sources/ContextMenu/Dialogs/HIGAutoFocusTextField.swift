// HIGAutoFocusTextField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keeps initial text input focus scoped to the current SwiftUI dialog.

import AppKit
import SwiftUI

// MARK: - HIGAutoFocusTextField
struct HIGAutoFocusTextField: ViewModifier {
    func body(content: Content) -> some View {
        content.background(HIGAutoFocusProbe())
    }
}

// MARK: - HIGAutoFocusProbe
private struct HIGAutoFocusProbe: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
        context.coordinator.scheduleFocusAttempts()
    }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.cancelFocusAttempts()
    }
}

// MARK: - HIGAutoFocusProbe Coordinator
private extension HIGAutoFocusProbe {
    @MainActor
    final class Coordinator {
        private weak var anchorView: NSView?
        private var scheduledWorkItems: [DispatchWorkItem] = []
        private var didSelectInitialText = false
        private let focusDelays: [TimeInterval] = [0, 0.08, 0.20]
        // MARK: - Attach
        func attach(to view: NSView) {
            anchorView = view
        }
        // MARK: - Schedule Focus Attempts
        @MainActor
        func scheduleFocusAttempts() {
            guard scheduledWorkItems.isEmpty else { return }
            for (index, delay) in focusDelays.enumerated() {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.performFocusAttempt(index: index + 1)
                }
                scheduledWorkItems.append(workItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
        // MARK: - Cancel Focus Attempts
        func cancelFocusAttempts() {
            scheduledWorkItems.forEach { $0.cancel() }
            scheduledWorkItems.removeAll()
        }
        // MARK: - Perform Focus Attempt
        private func performFocusAttempt(index: Int) {
            guard let anchorView,
                  let textField = nearestEditableTextField(from: anchorView),
                  let window = textField.window
            else { return }
            let didFocus = window.makeFirstResponder(textField)
            if didFocus {
                if !didSelectInitialText {
                    textField.selectText(nil)
                    didSelectInitialText = true
                }
                log.debug("[HIGAutoFocus] focused scoped text field on attempt \(index)")
            } else {
                log.debug("[HIGAutoFocus] failed scoped text field focus on attempt \(index)")
            }
        }
        // MARK: - Nearest Editable Text Field
        private func nearestEditableTextField(from view: NSView) -> NSTextField? {
            var current: NSView? = view
            while let node = current {
                if let found = firstEditableTextField(in: node) {
                    return found
                }
                current = node.superview
            }
            return nil
        }
        // MARK: - First Editable Text Field
        private func firstEditableTextField(in view: NSView) -> NSTextField? {
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
}

// MARK: - View Extension
extension View {
    func higAutoFocusTextField() -> some View {
        modifier(HIGAutoFocusTextField())
    }
}
