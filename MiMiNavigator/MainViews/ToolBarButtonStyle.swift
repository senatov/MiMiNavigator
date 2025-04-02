//
//  ToolBarButtonStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

struct ToolBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .cornerRadius(3)
            .shadow(color: Color.gray.opacity(0.4), radius: 6, x: 0, y: 5) // Тень только на фоне кнопки
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
