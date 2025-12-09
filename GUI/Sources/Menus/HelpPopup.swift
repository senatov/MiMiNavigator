//
// HelpPopup.swift
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
            .foregroundStyle(Color(#colorLiteral(red: 0.5787474513, green: 0.3215198815, blue: 0, alpha: 1)))
            .padding(8)
            .background(FilePanelStyle.yellowSelRowFill)
            .clipShape(.rect(cornerRadius: 8))
            .frame(width: 200)
    }
}
