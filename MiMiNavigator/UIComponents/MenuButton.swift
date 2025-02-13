//
//  MenuButton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

// Вспомогательный компонент для кнопок меню
import SwiftUI

struct MenuButton: View {
    let label: String
    let systemImage: String

    var body: some View {
        Button(action: {
            LoggerManager.log.debug("\(label) button pressed")
        }) {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)  // Компактный стиль
        }
    }
}
