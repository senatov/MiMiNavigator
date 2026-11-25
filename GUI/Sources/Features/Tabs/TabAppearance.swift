import AppKit
import SwiftUI

// MARK: - Tab Appearance Defaults
enum TabAppearance {
    static let fontSize = 13.0
    static let stripHeight: CGFloat = 26
    static let compactTabHeight: CGFloat = 22
    static let separatorColor = "#858B94"
    static let separatorWidth = 0.75
    static let separatorShadow = 0.15
    static let height: CGFloat = 29
    static let bottomRadius = 12.0
    static let inactivePanelOpacity = 0.65
    static let focusedBackground = "#EAF3FC"
    static let unfocusedBackground = "#EAEAEA"
    static let focusedText = "#5E5E5E"
    static let unfocusedText = "#656B74"
    static let darkFocusedBackground = "#415A78"
    static let darkUnfocusedBackground = "#424A58"
    static let darkFocusedText = "#F3F7FC"
    static let darkUnfocusedText = "#D4DCE8"
}

// MARK: - Tab Typeface
enum TabTypeface: String, CaseIterable {
    case system = "System"
    case rounded = "Rounded"
    case serif = "Serif"
    case monospaced = "Monospaced"

    // MARK: - Font Design
    var design: Font.Design {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

// MARK: - Shared Tab Label
struct TabAppearanceLabel: View {
    let title: String
    let systemIcon: String
    var compact = false
    let isSelected: Bool
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("tabs.appearance.typeface") private var typeface = TabTypeface.system
    @AppStorage("tabs.appearance.fontSize") private var fontSize = TabAppearance.fontSize
    @AppStorage("tabs.appearance.focusedText") private var focusedTextHex = TabAppearance.focusedText
    @AppStorage("tabs.appearance.unfocusedText") private var unfocusedTextHex = TabAppearance.unfocusedText

    var body: some View {
        HStack(spacing: 5) {
            Group {
                if compact {
                    Image(systemName: systemIcon)
                        .foregroundStyle(isSelected && isFocused ? Color.accentColor : .secondary)
                } else {
                    Image(systemName: systemIcon)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.blue, Color.orange)
                }
            }
            .font(.system(size: compact ? 11 : 13, weight: .regular))
            .frame(width: compact ? 13 : 14)
            .accessibilityHidden(true)
            Text(title)
                .font(.system(
                    size: fontSize,
                    weight: compact ? (isSelected ? .regular : .light) : (isSelected && isFocused ? .medium : .regular),
                    design: compact ? typeface.design : .default
                ))
                .lineLimit(1)
                .foregroundStyle(textColor)
                .truncationMode(.middle)
        }
    }

    // MARK: - Text Color
    private var textColor: Color {
        let stored = isFocused ? focusedTextHex : unfocusedTextHex
        let standard = isFocused ? TabAppearance.focusedText : TabAppearance.unfocusedText
        let dark = isFocused ? TabAppearance.darkFocusedText : TabAppearance.darkUnfocusedText
        let color = Color(hex: colorScheme == .dark && stored == standard ? dark : stored) ?? .primary
        return compact || isSelected || !isFocused ? color : color.opacity(0.78)
    }
}

// MARK: - Tab Separator
struct TabSeparator: View {
    @AppStorage("tabs.appearance.separatorColor") private var color = TabAppearance.separatorColor
    @AppStorage("tabs.appearance.separatorWidth") private var width = TabAppearance.separatorWidth
    @AppStorage("tabs.appearance.separatorShadow") private var shadow = TabAppearance.separatorShadow

    // MARK: - Body
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 6, y: 1))
            path.addLine(to: CGPoint(x: 2, y: 15))
        }
        .stroke(
            Color(hex: color) ?? Color(nsColor: .separatorColor),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
        .shadow(color: .black.opacity(shadow), radius: 1, x: 1, y: 0.5)
        .frame(width: 8, height: 16)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
