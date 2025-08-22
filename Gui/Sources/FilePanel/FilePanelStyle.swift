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
    static let dirNameColor = Color(#colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1))
    static let fileNameColor = Color(#colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1))
    static let selectedRowFill = Color(#colorLiteral(red: 0.9995340705, green: 0.9802359024, blue: 0.9185159122, alpha: 1))
    static let selectedRowStroke = Color(#colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1))
    static let symlinkDirNameColor = Color(#colorLiteral(red: 0.2392156863, green: 0.2901960784, blue: 0.8745098039, alpha: 1))

    // Layout
    static let iconSize: CGFloat = 18
    static let modifiedColumnWidth: CGFloat = 110
    static let selectedBorderWidth: CGFloat = 0.7
    static let sizeColumnWidth: CGFloat = 120
}
