import AppKit

// MARK: - Explicit window replacement
@MainActor
enum WindowReplacement {
    // MARK: - Retire previous presentation
    /// Used only by explicit open actions, never by application activation.
    static func close(_ window: NSWindow?) {
        guard let window else { return }
        window.makeFirstResponder(nil)
        window.delegate = nil
        window.close()
        window.contentView = nil
    }
}
