import AppKit
import SwiftUI

// MARK: - Tab Appearance Defaults
enum TabAppearance {
    static let fontSize = 13.0
    // MARK: - Compact Tab Height
    static func compactTabHeight(for font: NSFont) -> CGFloat {
        max(22, ceil(font.ascender - font.descender + max(0, font.leading)) + 4)
    }
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

// MARK: - Tab Font Preference
struct TabFontPreference: DynamicProperty {
    @AppStorage("tabs.appearance.font") private var archive = Data()
    @AppStorage("tabs.appearance.typeface") private var legacyTypeface = "System"
    @AppStorage("tabs.appearance.fontSize") private var legacySize = TabAppearance.fontSize

    // MARK: - Font
    var font: NSFont {
        let system = NSFont.systemFont(ofSize: legacySize, weight: .light)
        guard !archive.isEmpty else {
            let design: NSFontDescriptor.SystemDesign = switch legacyTypeface {
            case "Rounded": .rounded
            case "Serif": .serif
            case "Monospaced": .monospaced
            default: .default
            }
            guard let descriptor = system.fontDescriptor.withDesign(design) else { return system }
            return NSFont(descriptor: descriptor, size: legacySize) ?? system
        }
        return (try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSFont.self, from: archive)) ?? system
    }

    // MARK: - Store Font
    func store(_ font: NSFont) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: font, requiringSecureCoding: true) else { return }
        archive = data
    }

    // MARK: - Reset Font
    func reset() {
        archive = Data()
        legacyTypeface = "System"
        legacySize = TabAppearance.fontSize
    }
}

// MARK: - Shared Tab Label
struct TabAppearanceLabel: View {
    let title: String
    let systemIcon: String
    var compactFont: NSFont? = nil
    private var compact: Bool { compactFont != nil }
    let isSelected: Bool
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
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
                .font(compactFont.map { Font($0) }
                    ?? .system(size: fontSize, weight: isSelected && isFocused ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(textColor)
                .truncationMode(.middle)
        }
    }

    // MARK: - Text Color
    private var textColor: Color {
        let usesFocusedText = isFocused && (!compact || isSelected)
        let stored = usesFocusedText ? focusedTextHex : unfocusedTextHex
        let standard = usesFocusedText ? TabAppearance.focusedText : TabAppearance.unfocusedText
        let dark = usesFocusedText ? TabAppearance.darkFocusedText : TabAppearance.darkUnfocusedText
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
