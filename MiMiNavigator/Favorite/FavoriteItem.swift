//
//  FavoriteItem.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftUI

struct FavoriteItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String // SF Symbols icon name for simplicity
}
