import SwiftUI

// MARK: - Volume Usage Indicator
struct VolumeUsageIndicator: View {
    let used: Double
    private let raspberry = Color(#colorLiteral(red: 0.52, green: 0.04, blue: 0.24, alpha: 1))

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * used
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    if width > 0 {
                        Capsule()
                            .fill(raspberry)
                            .frame(width: width)
                            .glassEffect(.regular.tint(raspberry), in: .capsule)
                    }
                }
        }
        .frame(height: 7)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disk space used")
        .accessibilityValue(used.formatted(.percent.precision(.fractionLength(0))))
    }
}
