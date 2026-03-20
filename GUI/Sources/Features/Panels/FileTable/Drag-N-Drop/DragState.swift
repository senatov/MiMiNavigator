//
//  DragState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

struct DragState {
    var startPoint: NSPoint?
    var didStart: Bool
    var isResize: Bool
}
