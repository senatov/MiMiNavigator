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
            .foregroundColor(Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(#colorLiteral(red: 1, green: 0.9994689267, blue: 0.9418378656, alpha: 1)))
                    .shadow(radius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(#colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)), lineWidth: 0.5)
            )
            .shadow(color: Color(#colorLiteral(red: 0.7540688515, green: 0.7540867925, blue: 0.7540771365, alpha: 1)), radius: 12)
            .fixedSize()
            .padding(5)
    } 
}

struct PrettyTooltip_Previews: PreviewProvider {
    static var previews: some View {
        PrettyTooltip(text: "This is some ToolTip, Hurra!")
            .frame(height: 40)
    }
}

#Preview {
    PrettyTooltip(text: "This is some ToolTip, Hurra!")
        .frame(height: 40)
}


