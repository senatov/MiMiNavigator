import AppKit

// MARK: - Tab Font Panel
@MainActor
final class TabFontPanel: NSObject, NSWindowDelegate {
    private var font: NSFont?
    private var onChange: ((NSFont) -> Void)?
    private weak var previousTarget: AnyObject?
    private weak var previousDelegate: (any NSWindowDelegate)?
    private var previousFont: NSFont?
    private var previousMultiple = false

    // MARK: - Show
    func show(font: NSFont, onChange: @escaping (NSFont) -> Void) {
        let manager = NSFontManager.shared
        guard let panel = manager.fontPanel(true) else { return }
        if manager.target as AnyObject? !== self {
            previousTarget = manager.target as AnyObject?
            previousDelegate = panel.delegate
            previousFont = manager.selectedFont
            previousMultiple = manager.isMultiple
        }
        self.font = font
        self.onChange = onChange
        manager.target = self
        panel.delegate = self
        manager.setSelectedFont(font, isMultiple: false)
        manager.orderFrontFontPanel(nil)
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - Change Font
    @objc func changeFont(_ sender: NSFontManager) {
        guard let font else { return }
        let converted = sender.convert(font)
        self.font = converted
        sender.setSelectedFont(converted, isMultiple: false)
        onChange?(converted)
    }

    // MARK: - Close
    func close() {
        let manager = NSFontManager.shared
        guard manager.target as AnyObject? === self else { return }
        manager.fontPanel(false)?.close()
    }

    // MARK: - Restore Font Panel
    func windowWillClose(_ notification: Notification) {
        let manager = NSFontManager.shared
        manager.target = previousTarget
        (notification.object as? NSWindow)?.delegate = previousDelegate
        if let previousFont {
            manager.setSelectedFont(previousFont, isMultiple: previousMultiple)
        }
        previousFont = nil
        onChange = nil
        font = nil
    }
}
