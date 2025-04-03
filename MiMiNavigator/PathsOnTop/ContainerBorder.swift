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
            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
    }
}

#Preview {
    ContainerBorder()
        .frame(width: 200, height: 100)
        .padding()
        .background(Color.blue.opacity(0.2))
}
