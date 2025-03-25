//
//  ContainerBackground.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct ContainerBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
    }
}
