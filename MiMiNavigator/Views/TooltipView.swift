// TooltipView.swift
// A reusable tooltip view component that can display text at a specified position.
// Created by Iakov Senatov

import SwiftUI
import SwiftyBeaver

// MARK: - -

struct TooltipView: View {
    let text: String
    let position: CGPoint
    // Initialize logger
    var backgroundColor: Color = Color.yellow.opacity(0.6) // Default background color

    var body: some View {
        Text(text)
            .padding(8)
            .background(backgroundColor)
            .cornerRadius(5)
            .position(position)
    }
}


// MARK: - - Preview for TooltipView

struct TooltipView_Previews: PreviewProvider {
    static var previews: some View {
        TooltipView(text: "This is a tooltip", position: CGPoint(x: 100, y: 100))
            .previewLayout(.sizeThatFits)
    }
}
