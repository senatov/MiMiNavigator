// TooltipView.swift
// A reusable tooltip view component that can display text at a specified position.
// Created by Iakov Senatov

import SwiftUI
import SwiftyBeaver

// MARK: -

struct TooltipView: View {
    let text: String
    let position: CGPoint

    var body: some View {
        Text(text)
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(3)
            .foregroundColor(.white)
            .position(position)
    }
}

// MARK: - Preview for TooltipView
struct TooltipView_Previews: PreviewProvider {
    static var previews: some View {
        TooltipView(text: "This is a tooltip", position: CGPoint(x: 100, y: 100))
            .previewLayout(.sizeThatFits)
    }
}
