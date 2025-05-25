    //
    //  EditablePathItem.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.05.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI
import SwiftyBeaver

    // MARK: -
    /// - Helper structure for path items
struct EditablePathItem: Identifiable, Hashable, CustomStringConvertible {
    
    let titleStr: String
    let pathStr: String
    let icon: NSImage
    var id: String { pathStr }
    
    var description: String {
        "EditablePathItem(title: \(titleStr), path: \(pathStr))"
    }
}
