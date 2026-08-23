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
    // MARK: - Apply
    @MainActor
    static func apply(_ role: WindowPresentationRole, to panel: NSPanel) {
        switch role {
        case .standalone:
            panel.isFloatingPanel = false
            panel.hidesOnDeactivate = false
            panel.level = .normal
        case .transientPopup:
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = true
            panel.level = .floating
        case .modalDecision, .progress:
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = true
            panel.level = .modalPanel
        }
        panel.tabbingMode = .disallowed
    }
}
