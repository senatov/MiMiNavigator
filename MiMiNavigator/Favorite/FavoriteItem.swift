    //
    //  FavoriteItem.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 10.11.24.
    //  Copyright © 2024 Senatov. All rights reserved.
    //

import SwiftUI

    // MARK: -
struct FavoriteItem: Identifiable, CustomStringConvertible {
    let id = UUID()
    let nameStr: String
    let iconStr: String
    
        // MARK: -
    init(name: String, icon: String) {
        self.nameStr = name
        self.iconStr = icon
    }
    
        // MARK: -
    public var description: String {
        "FavoriteItem(name: \(nameStr), icon: \(iconStr))"
    }
    
}
