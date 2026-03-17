// PopupEventMonitors.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: @MainActor helper that owns NSEvent local monitors + NSNotification observer.
//   @MainActor isolation fixes all Swift 6 concurrency warnings:
//     • NSPanel.isVisible accessed only on main actor
//     • onHide/onClickOutside closures sent only on main actor — no data race
//   Monitor objects (Any?) are stored nonisolated(unsafe) so deinit can release
//   them without hopping to MainActor — NSEvent.removeMonitor is documented
//   thread-safe and the Any? pointers are never mutated concurrently after deinit.

import AppKit
import Foundation

// MARK: - PopupEventMonitors

/// Lifecycle: create → install(...) → remove() / deinit auto-removes.
@MainActor
final class PopupEventMonitors {

    // nonisolated(unsafe): safe because NSEvent monitors are opaque thread-safe tokens;
    // written only on MainActor, read only in deinit after all MainActor work is done.
    nonisolated(unsafe) private var clickMonitor: Any?
    nonisolated(unsafe) private var escMonitor: Any?
    nonisolated(unsafe) private var focusObserver: Any?

    init() {}

    // MARK: - Install

    /// Install click-outside, ESC, and optionally app-resign monitors.
    ///
    /// - Parameters:
    ///   - panel: The floating NSPanel whose own clicks should NOT trigger dismiss.
    ///   - onHide: Called on MainActor when any dismiss trigger fires.
    ///   - onClickOutside: Extra callback after `onHide` on click/ESC (autocomplete etc.). Optional.
    ///   - shouldDismissOnClick: Guard — return false to suppress dismiss for a click. Optional.
    ///   - installResignObserver: Set false to skip NSApp-resign observer. Default true.
    func install(
        panel: NSPanel,
        onHide: @escaping @MainActor () -> Void,
        onClickOutside: (@MainActor () -> Void)? = nil,
        shouldDismissOnClick: (@MainActor (NSEvent) -> Bool)? = nil,
        installResignObserver: Bool = true
    ) {
        remove()

        clickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak panel] event in
            guard let p = panel else { return event }
            Task { @MainActor in
                guard p.isVisible else { return }
                if event.window === p { return }
                if let guard_ = shouldDismissOnClick, !guard_(event) { return }
                onHide()
                onClickOutside?()
            }
            return event
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak panel] event in
            guard let p = panel, event.keyCode == 53 else { return event }
            Task { @MainActor in
                guard p.isVisible else { return }
                onHide()
                onClickOutside?()
            }
            return nil
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

    // MARK: - Remove (MainActor)

    func remove() {
        if let m = clickMonitor  { NSEvent.removeMonitor(m);                     clickMonitor  = nil }
        if let m = escMonitor    { NSEvent.removeMonitor(m);                     escMonitor    = nil }
        if let m = focusObserver { NotificationCenter.default.removeObserver(m); focusObserver = nil }
    }

    // MARK: - deinit
    // nonisolated(unsafe) fields allow cleanup here without MainActor hop.
    // NSEvent.removeMonitor and NotificationCenter.removeObserver are thread-safe.
    deinit {
        if let m = clickMonitor  { NSEvent.removeMonitor(m) }
        if let m = escMonitor    { NSEvent.removeMonitor(m) }
        if let m = focusObserver { NotificationCenter.default.removeObserver(m) }
    }
}
