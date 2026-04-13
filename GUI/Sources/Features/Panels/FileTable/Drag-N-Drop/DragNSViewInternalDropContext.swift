//
//  DragNSViewInternalDropContext.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

struct DragNSViewInternalDropContext {
    let manager: DragDropManager
    let appState: AppState
    let sourceSide: FavPanelSide
    let window: NSWindow
    let files: [CustomFile]
}
