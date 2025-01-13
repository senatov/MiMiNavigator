//
//  MenuItem.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.01.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
    let shortcut: String?
}
