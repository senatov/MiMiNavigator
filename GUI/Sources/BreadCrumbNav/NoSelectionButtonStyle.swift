//
//  NoSelectionButtonStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FavoritesKit
import FileModelKit
import SwiftUI

struct NoSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)  // subtle feedback, no selection
    }
}
