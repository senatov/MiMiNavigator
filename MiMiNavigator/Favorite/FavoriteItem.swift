//
//  FavoriteItem.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct FavoriteItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String

    // MARK: -
    init(name: String, icon: String) {
        self.name = name
        self.icon = icon
    }

}
