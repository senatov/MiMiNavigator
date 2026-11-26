import SwiftUI

// MARK: - Volumes Menu Preference
struct VolumesMenuPreference: PreferenceKey {
    struct Menu {
        let anchor: Anchor<CGRect>
        let content: AnyView
        let dismiss: () -> Void
    }

    static var defaultValue: Menu? { nil }

    static func reduce(value: inout Menu?, nextValue: () -> Menu?) {
        value = nextValue() ?? value
    }
}

// MARK: - Volumes Menu Overlay
struct VolumesMenuOverlay: View {
    let menu: VolumesMenuPreference.Menu

    var body: some View {
        GeometryReader { geometry in
            let trigger = geometry[menu.anchor]
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: menu.dismiss)
                    .accessibilityHidden(true)
                menu.content
                    .offset(x: max(0, trigger.minX - 40), y: trigger.maxY + 4)
            }
        }
    }
}
