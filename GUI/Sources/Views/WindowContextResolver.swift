import AppKit

// MARK: - Window Context Resolver
@MainActor
enum WindowContextResolver {
    // MARK: - Presentation Host
    static func presentationHost(excluding excludedWindow: NSWindow? = nil, preferMain: Bool = false) -> NSWindow? {
        let preferred = preferMain ? [NSApp.mainWindow, NSApp.keyWindow] : [NSApp.keyWindow, NSApp.mainWindow]
        for candidate in preferred.compactMap({ $0 }) where isSuitableHost(candidate, excluding: excludedWindow) {
            return candidate
        }
        return NSApp.orderedWindows.first { isSuitableHost($0, excluding: excludedWindow) }
    }

    // MARK: - Positioning Reference
    static func positioningWindow(excluding excludedWindow: NSWindow? = nil) -> NSWindow? {
        let candidates = [NSApp.mainWindow, NSApp.keyWindow].compactMap { $0 } + NSApp.orderedWindows
        return candidates.first {
            $0 !== excludedWindow && $0.isVisible && !$0.isMiniaturized && isApplicationWindow($0)
        }
    }

    private static func isSuitableHost(_ window: NSWindow, excluding excludedWindow: NSWindow?) -> Bool {
        window !== excludedWindow
            && window.isVisible
            && !window.isMiniaturized
            && window.attachedSheet == nil
            && isApplicationWindow(window)
    }

    private static func isApplicationWindow(_ window: NSWindow) -> Bool {
        guard let panel = window as? NSPanel else { return true }
        return WindowPresentationPolicy.isStandalone(panel)
    }
}
