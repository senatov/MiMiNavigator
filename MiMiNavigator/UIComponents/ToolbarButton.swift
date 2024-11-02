// ToolbarButton.swift
// A reusable toolbar button component with customizable title, icon, and action.
// Created by Iakov Senatov

import SwiftUI
import SwiftyBeaver

// MARK: - -

struct ToolbarButton: View {
    let title: String
    let icon: String? // Optional icon name from SF Symbols or custom icon
    let action: () -> Void
    @State private var isPressed = false
    // Initialize logger

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.purple.opacity(0.4), radius: 5, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0) // Scale effect when pressed
        }
        .buttonStyle(.borderless) 
        .foregroundColor(Color.primary.opacity(0.9)) // Set background color
        .onChange(of: isPressed) {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed.toggle()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// Preview for ToolbarButton

// MARK: - -

struct ToolbarButton_Previews: PreviewProvider {
    static var previews: some View {
        ToolbarButton(title: "Save", icon: "square.and.arrow.down") {
            log.debug("Button tapped")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
