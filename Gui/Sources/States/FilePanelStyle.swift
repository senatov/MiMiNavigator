//
//  FilePanelStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

enum FilePanelStyle {
    // Colors
    static let dirNameColor = Color(#colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1))
    static let symlinkDirNameColor = Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1))
    static let fileNameColor = Color(#colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1))
    static let selectedRowFill = Color(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.4980392158))
    static let selectedRowStroke = Color.orange

    // Layout
    static let iconSize: CGFloat = 16
    static let sizeColumnWidth: CGFloat = 80
    static let modifiedColumnWidth: CGFloat = 120
}
