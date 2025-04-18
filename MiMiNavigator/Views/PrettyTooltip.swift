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
            .font(.system(size: 13))
            .foregroundColor(Color(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(#colorLiteral(red: 1, green: 0.9994689267, blue: 0.9418378656, alpha: 1)))
                    .shadow(radius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(#colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)), lineWidth: 0.5)
            )
            .fixedSize()
    }
}

struct PrettyTooltip_Previews: PreviewProvider {
    static var previews: some View {
        PrettyTooltip(text: "This is some ToolTip, Hurra!")
            .frame(height: 40)
    }
}
