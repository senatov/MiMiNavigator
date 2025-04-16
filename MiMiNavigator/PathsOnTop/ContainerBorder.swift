//
//  ContainerBorder.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Background and Border

struct ContainerBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
    }
}
