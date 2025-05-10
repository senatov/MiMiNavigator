//
//  SelectedPanel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

public enum PanelSide {
    case left, right, nothing
}

public class SelectedPanel: ObservableObject {
    // initial is nothing - no panels selected on start.
    // FIXME: but later schould be saved in  Properties
    @Published var panelSide: PanelSide = PanelSide.nothing
}
