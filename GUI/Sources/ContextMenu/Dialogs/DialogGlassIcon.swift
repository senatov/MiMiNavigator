import SwiftUI

// MARK: - Dialog Glass Icon
struct DialogGlassIcon: View {
    static let destructiveTint = Color(nsColor: #colorLiteral(red: 0.64, green: 0.29, blue: 0.32, alpha: 1))

    let systemName: String
    let tint: Color
    var diameter: CGFloat = 64

    var body: some View {
        Circle()
            .fill(.clear)
            .frame(width: diameter, height: diameter)
            .glassEffect(.regular.tint(tint.opacity(0.18)), in: .circle)
            .overlay {
                Image(systemName: systemName)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: diameter * 0.51, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: .black.opacity(0.14), radius: 0.75, y: 1)
            }
            .accessibilityHidden(true)
    }
}
