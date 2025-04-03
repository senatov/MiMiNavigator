//
//  MenuButton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

// Вспомогательный компонент для кнопок меню
import SwiftUI

struct MenuButtonView: View {
    let label: String
    let systemImage: String

    var body: some View {
        Button(action: {
            LogMan.log.debug("\(label) button pressed")
        }) {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)  // Компактный стиль
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MenuButtonView(label: "Settings", systemImage: "gearshape.fill")
        .padding()
        .background(Color.gray.opacity(0.1))
}
