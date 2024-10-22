import SwiftUI

    /// TooltipView is a reusable view that displays the tooltip text at a specific position.
struct TooltipView: View {
    let text: String
    let position: CGPoint
    
    var body: some View {
        Text(text)
            .padding(8)
            .background(Color.yellow.opacity(0.5)) // Lighter yellow background
            .cornerRadius(5)
            .position(position)
    }
}
