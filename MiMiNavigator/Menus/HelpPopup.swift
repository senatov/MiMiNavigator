//
//  HelpPopup.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -

struct HelpPopup: View {
    let text: String
    var body: some View {
        log.info(#function)
        return Text(text)
            .font(.system(size: 12))
            .foregroundColor(Color(#colorLiteral(red: 0.5787474513, green: 0.3215198815, blue: 0, alpha: 1)))
            .padding(8)
            .background(Color(#colorLiteral(red: 0.9995340705, green: 0.9802359024, blue: 0.9185159122, alpha: 1)))
            .cornerRadius(3)
            .frame(width: 200)
    }
}
