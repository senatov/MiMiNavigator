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
public struct EditablePathItem: Identifiable, Hashable {
    public let titleStr: String
    public let pathStr: String
    public let icon: NSImage
    public var id: String { pathStr }
}
