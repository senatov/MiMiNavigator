import AppKit
import SwiftUI

// MARK: - Tab Appearance Defaults
enum TabAppearance {
    static let fontSize = 15.0
    static let height: CGFloat = 29
    static let bottomRadius = 12.0
    static let inactivePanelOpacity = 0.58
    static let focusedBackground = "#EAF3FC"
    static let unfocusedBackground = "#EAEAEA"
    static let focusedText = "#10243D"
    static let unfocusedText = "#929292"
    static let darkFocusedBackground = "#415A78"
    static let darkUnfocusedBackground = "#424A58"
    static let darkFocusedText = "#F3F7FC"
    static let darkUnfocusedText = "#D4DCE8"
}

// MARK: - Shared Tab Label
struct TabAppearanceLabel: View {
    let title: String
    let systemIcon: String
    var fileIcon: NSImage? = nil
    let isSelected: Bool
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("tabs.appearance.fontSize") private var fontSize = TabAppearance.fontSize
    @AppStorage("tabs.appearance.focusedText") private var focusedTextHex = TabAppearance.focusedText
    @AppStorage("tabs.appearance.unfocusedText") private var unfocusedTextHex = TabAppearance.unfocusedText

    var body: some View {
        HStack(spacing: 5) {
            if let fileIcon {
                Image(nsImage: fileIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: systemIcon)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.blue, Color.orange)
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 14)
            }
            Text(title)
                .font(.system(size: CGFloat(fontSize), weight: .regular))
                .lineLimit(1)
                .foregroundStyle(textColor)
        }
    }

    private var textColor: Color {
        let stored = isFocused ? focusedTextHex : unfocusedTextHex
        let standard = isFocused ? TabAppearance.focusedText : TabAppearance.unfocusedText
        let dark = isFocused ? TabAppearance.darkFocusedText : TabAppearance.darkUnfocusedText
        let color = Color(hex: colorScheme == .dark && stored == standard ? dark : stored) ?? .primary
        return isSelected || !isFocused ? color : color.opacity(0.78)
    }
}
