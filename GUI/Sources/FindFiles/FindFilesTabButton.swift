import SwiftUI

// MARK: - Search Tab Button
struct FindFilesTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.controlActiveState) private var activeState
    @AppStorage("tabs.appearance.bottomRadius") private var bottomRadius = TabAppearance.bottomRadius
    var body: some View {
        Button(action: action) {
            TabAppearanceLabel(
                title: title,
                systemIcon: icon,
                isSelected: isSelected,
                isFocused: activeState != .inactive
            )
                .padding(.horizontal, 12)
                .frame(minWidth: 95)
                .frame(height: TabAppearance.height)
                .background {
                    PanelTabSurface(isActive: isSelected, isPanelFocused: activeState != .inactive, isHovered: isHovered)
                }
                .contentShape(BottomSheetTabShape(bottomRadius: CGFloat(bottomRadius)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
