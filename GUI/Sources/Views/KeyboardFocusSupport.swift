// KeyboardFocusSupport.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared keyboard focus modifiers for Windows-style Tab navigation.

import AppKit
import SwiftUI

// MARK: - AppKit key view navigation
@MainActor
private enum KeyboardFocusNavigator {
    static func move(backward: Bool) -> KeyPress.Result {
        guard let window = NSApp.keyWindow else { return .ignored }
        window.recalculateKeyViewLoop()
        if backward {
            window.selectPreviousKeyView(nil)
        } else {
            window.selectNextKeyView(nil)
        }
        return .handled
    }
}

// MARK: - Dialog Tab event bridge
private struct DialogTabNavigationBridge: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private weak var window: NSWindow?
        private var monitor: Any?

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            stop()
            self.window = window
            window.recalculateKeyViewLoop()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.window, event.keyCode == 48 else { return event }
                self.window?.recalculateKeyViewLoop()
                if event.modifierFlags.contains(.shift) {
                    self.window?.selectPreviousKeyView(nil)
                } else {
                    self.window?.selectNextKeyView(nil)
                }
                return nil
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            window = nil
        }
    }
}

// MARK: - Keyboard focus support
extension View {
    func keyboardFocusSection() -> some View {
        focusSection()
            .focusEffectDisabled()
            .onKeyPress(phases: .down) { press in
                guard press.key == .tab else { return .ignored }
                return KeyboardFocusNavigator.move(backward: press.modifiers.contains(.shift))
            }
    }

    func keyboardFocusable() -> some View {
        focusable(true)
            .focusEffectDisabled()
    }

    func forcedDialogTabNavigation() -> some View {
        background(DialogTabNavigationBridge().frame(width: 0, height: 0))
    }
}
