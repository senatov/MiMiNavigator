import AppKit
import SwiftUI

// MARK: - Context Menu Label
struct ContextMenuLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            ContextMenuSymbol(name: systemImage)
        }
        .labelStyle(.titleAndIcon)
    }
}

// MARK: - Context Menu Symbol
struct ContextMenuSymbol: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String

    var body: some View {
        if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold).applying(.init(paletteColors: [ink]))) {
            Image(nsImage: symbol)
                .renderingMode(.original)
        }
    }

    private var ink: NSColor {
        switch name {
            case "trash", "trash.fill", "xmark", "xmark.square":
                return colorScheme == .dark
                    ? #colorLiteral(red: 0.94, green: 0.61, blue: 0.63, alpha: 1)
                    : #colorLiteral(red: 0.56, green: 0.19, blue: 0.23, alpha: 1)
            case "terminal", "terminal.fill", "apple.terminal.fill":
                return colorScheme == .dark
                    ? #colorLiteral(red: 0.58, green: 0.84, blue: 0.70, alpha: 1)
                    : #colorLiteral(red: 0.14, green: 0.35, blue: 0.27, alpha: 1)
            default:
                return colorScheme == .dark
                    ? #colorLiteral(red: 0.71, green: 0.83, blue: 0.94, alpha: 1)
                    : #colorLiteral(red: 0.21, green: 0.33, blue: 0.46, alpha: 1)
        }
    }
}
