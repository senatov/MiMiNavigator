// PopupEventMonitors.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Owns NSEvent local monitors + NSNotification observer for popup HUD panels.
//   Intentionally NOT @MainActor so deinit can safely release monitors without
//   nonisolated(unsafe) hacks. The owning controller holds a strong ref; setting
//   it to nil in deinit is all that's needed.

import AppKit
import Foundation

// MARK: - PopupEventMonitors

/// Lifecycle: create → install(...) → remove() / deinit auto-removes.
final class PopupEventMonitors {

    private var clickMonitor: Any?
    private var escMonitor: Any?
    private var focusObserver: Any?

    init() {}

    // MARK: - Install

    /// Install click-outside, ESC, and optionally app-resign monitors.
    ///
    /// - Parameters:
    ///   - panel: The floating NSPanel whose own clicks should NOT trigger dismiss.
    ///   - onHide: Called on main queue when any dismiss trigger fires.
    ///   - onClickOutside: Extra callback fired after `onHide` on click/ESC events
    ///     (used e.g. by autocomplete to notify the text field). Optional.
    ///   - shouldDismissOnClick: Guard closure — return false to suppress dismiss
    ///     for a specific click (e.g. click lands inside an anchor rect). Optional.
    ///   - installResignObserver: Set false to skip NSApp-resign observer. Default true.
    func install(
        panel: NSPanel,
        onHide: @escaping () -> Void,
        onClickOutside: (() -> Void)? = nil,
        shouldDismissOnClick: ((NSEvent) -> Bool)? = nil,
        installResignObserver: Bool = true
    ) {
        remove()

        clickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak panel] event in
            guard let p = panel, p.isVisible else { return event }
            if event.window === p { return event }
            if let guard_ = shouldDismissOnClick, !guard_(event) { return event }
            Task { @MainActor in onHide(); onClickOutside?() }
            return event
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak panel] event in
            guard let p = panel, p.isVisible else { return event }
            if event.keyCode == 53 {
                Task { @MainActor in onHide(); onClickOutside?() }
                return nil
            }
            return event
        }

        if installResignObserver {
            focusObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in onHide() }
            }
        }
    }

    // MARK: - Remove

    func remove() {
        if let m = clickMonitor  { NSEvent.removeMonitor(m);                         clickMonitor  = nil }
        if let m = escMonitor    { NSEvent.removeMonitor(m);                         escMonitor    = nil }
        if let m = focusObserver { NotificationCenter.default.removeObserver(m);     focusObserver = nil }
    }

    // MARK: - deinit — no nonisolated(unsafe) needed, class is not @MainActor

    deinit { remove() }
}
