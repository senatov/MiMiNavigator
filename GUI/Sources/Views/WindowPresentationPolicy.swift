import AppKit

// MARK: - Window Presentation Role
enum WindowPresentationRole {
    case standalone
    case transientPopup
    case modalDecision
    case progress
}

// MARK: - Window Presentation Policy
enum WindowPresentationPolicy {
    private static let standaloneIdentifier = NSUserInterfaceItemIdentifier("MiMiNavigator.Window.Standalone")
    private static let transientIdentifier = NSUserInterfaceItemIdentifier("MiMiNavigator.Window.Transient")
    private static let modalIdentifier = NSUserInterfaceItemIdentifier("MiMiNavigator.Window.ModalDecision")
    private static let progressIdentifier = NSUserInterfaceItemIdentifier("MiMiNavigator.Window.Progress")

    // MARK: - Apply
    @MainActor
    static func apply(_ role: WindowPresentationRole, to panel: NSPanel) {
        switch role {
        case .standalone:
            panel.identifier = standaloneIdentifier
            panel.isFloatingPanel = false
            panel.hidesOnDeactivate = false
            panel.level = .normal
        case .transientPopup:
            panel.identifier = transientIdentifier
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = true
            panel.level = .floating
        case .modalDecision:
            panel.identifier = modalIdentifier
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = true
            panel.level = .modalPanel
        case .progress:
            panel.identifier = progressIdentifier
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = true
            panel.level = .modalPanel
        }
        panel.tabbingMode = .disallowed
    }

    // MARK: - Present Standalone
    @MainActor
    static func presentStandalone(_ panel: NSPanel) {
        let host = WindowContextResolver.presentationHost(excluding: panel, preferMain: true)
        NSApp.activate(ignoringOtherApps: true)
        order(panel, above: host, makeKey: true)
        DispatchQueue.main.async { [weak panel, weak host] in
            guard let panel, panel.isVisible else { return }
            order(panel, above: host, makeKey: true)
        }
    }

    // MARK: - Raise Standalone
    @MainActor
    static func raiseStandalone(_ panel: NSPanel) {
        let host = WindowContextResolver.presentationHost(excluding: panel, preferMain: true)
        order(panel, above: host, makeKey: false)
    }

    // MARK: - Order Above Host
    @MainActor
    private static func order(_ panel: NSPanel, above host: NSWindow?, makeKey: Bool) {
        if let host, host.isVisible, !host.isMiniaturized {
            panel.order(.above, relativeTo: host.windowNumber)
        } else {
            panel.orderFront(nil)
        }
        if makeKey { panel.makeKey() }
    }

    // MARK: - Role Query
    @MainActor
    static func isStandalone(_ window: NSWindow) -> Bool {
        if window.identifier == standaloneIdentifier { return true }
        guard let panel = window as? NSPanel else { return false }
        return panel.styleMask.contains(.utilityWindow)
            && !panel.isFloatingPanel
            && !panel.hidesOnDeactivate
            && panel.level == .normal
    }
}
