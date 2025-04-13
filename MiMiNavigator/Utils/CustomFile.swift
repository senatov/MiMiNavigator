//
//  CustomFile.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftyBeaver

// MARK: - CustomFile: File & Folder Representation
struct CustomFile: Identifiable, Sendable {
    var id: UUID
    var name: String
    var path: String
    var isDirectory: Bool
    var children: [CustomFile]?

    /// Initializes a new instance of `CustomFile`
    init(name: String, path: String, isDirectory: Bool, children: [CustomFile]?) {
        self.id = UUID()  // ✅ new. added
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
    }
}
