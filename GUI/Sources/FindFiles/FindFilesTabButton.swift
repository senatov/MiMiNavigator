import SwiftUI

// MARK: - Search Tab Button
struct FindFilesTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.controlActiveState) private var activeState
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 12)
                .frame(minWidth: 95, minHeight: 29)
                .background {
                    PanelTabSurface(isActive: isSelected, isPanelFocused: activeState != .inactive, isHovered: isHovered)
                }
                .contentShape(BottomSheetTabShape())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
