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
            .foregroundStyle(FilePanelStyle.helpPopupTextColor)
            .padding(8)
            .background(FilePanelStyle.yellowSelRowFill)
            .clipShape(.rect(cornerRadius: FilePanelStyle.toolbarButtonRadius))
            .frame(width: 200)
    }
}
