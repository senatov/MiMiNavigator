//
//  PrettyTooltip.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
import SwiftUI

struct PrettyTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(Color(red: 0.18, green: 0.01, blue: 0.56))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.3))
                    .shadow(radius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
            )
            .fixedSize()
    }
}

struct PrettyTooltip_Previews: PreviewProvider {
    static var previews: some View {
        PrettyTooltip(text: "This is some ToolTip, Hurra!")
            .padding()
    }
}
