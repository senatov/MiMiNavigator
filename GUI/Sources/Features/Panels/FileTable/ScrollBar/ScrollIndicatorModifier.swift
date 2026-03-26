// ScrollIndicatorModifier.swift
// MiMiNavigator
//
// Description: SwiftUI ViewModifier that controls scroll indicator visibility
//              based on panel focus state and ScrollBarConfig.

import SwiftUI


// MARK: - ScrollIndicatorModifier

/// Shows or hides SwiftUI scroll indicators based on focus and config.
struct ScrollIndicatorModifier: ViewModifier {
    let isFocused: Bool


    func body(content: Content) -> some View {
        if ScrollBarConfig.hideScrollersOnInactivePanel {
            content.scrollIndicators(isFocused ? .automatic : .hidden)
        } else {
            content.scrollIndicators(.automatic)
        }
    }
}


extension View {

    /// Apply scroll indicator visibility rules from ScrollBarConfig.
    func panelScrollIndicators(isFocused: Bool) -> some View {
        modifier(ScrollIndicatorModifier(isFocused: isFocused))
    }
}
