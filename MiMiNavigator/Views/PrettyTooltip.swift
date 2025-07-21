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
            .font(.system(size: 13, weight: .regular, design: .default))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(#colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1)))  // less intense pale yellow background
                    .shadow(color: Color(#colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)), radius: 7, x: 2, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(#colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)), lineWidth: 0.4)  // light blue border
            )
            .foregroundColor(.black)
    }
}

#Preview {
    PrettyTooltip(text: "This is some ToolTip, Hurra!")
        .frame(height: 40)
}
