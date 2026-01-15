// AnimatedToolbarButton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 15.01.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Reusable animated toolbar button
struct AnimatedToolbarButton: View {
    let systemImage: String
    let activeImage: String?
    let help: String
    let shortcut: KeyEquivalent?
    let modifiers: EventModifiers
    let isToggle: Bool
    let activeColor: Color
    let inactiveColor: Color
    let action: () -> Void
    
    @State private var isAnimating = false
    @Binding var isActive: Bool
    
    init(
        systemImage: String,
        activeImage: String? = nil,
        help: String,
        shortcut: KeyEquivalent? = nil,
        modifiers: EventModifiers = .command,
        isToggle: Bool = false,
        isActive: Binding<Bool> = .constant(false),
        activeColor: Color = .orange,
        inactiveColor: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.activeImage = activeImage
        self.help = help
        self.shortcut = shortcut
        self.modifiers = modifiers
        self.isToggle = isToggle
        self._isActive = isActive
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.action = action
    }
    
    var body: some View {
        Button(action: performAction) {
            Image(systemName: currentImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(currentColor)
                .font(.system(size: 13, weight: .semibold))
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6), value: isAnimating)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help(help)
        .modifier(ShortcutModifier(shortcut: shortcut, modifiers: modifiers))
    }
    
    private var currentImage: String {
        if isToggle, let activeImage = activeImage {
            return isActive ? activeImage : systemImage
        }
        return systemImage
    }
    
    private var currentColor: Color {
        if isAnimating { return .orange }
        if isToggle { return isActive ? activeColor : inactiveColor }
        return inactiveColor
    }
    
    private func performAction() {
        guard !isAnimating else { return }
        
        withAnimation(.easeInOut(duration: 0.6)) {
            isAnimating = true
        }
        
        action()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                isAnimating = false
            }
        }
    }
}

// MARK: - Keyboard shortcut modifier
private struct ShortcutModifier: ViewModifier {
    let shortcut: KeyEquivalent?
    let modifiers: EventModifiers
    
    func body(content: Content) -> some View {
        if let shortcut = shortcut {
            content.keyboardShortcut(shortcut, modifiers: modifiers)
        } else {
            content
        }
    }
}
