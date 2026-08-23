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

    // MARK: - Role Query
    @MainActor
    static func isStandalone(_ window: NSWindow) -> Bool {
        window.identifier == standaloneIdentifier
    }
}
