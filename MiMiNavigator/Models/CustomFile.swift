//
//  CustomFile.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftyBeaver

// MARK: - -

struct CustomFile: Identifiable {
    // Initialize logger
    let log = SwiftyBeaver.self
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [CustomFile]? // Optional array for holding child files if it's a directory

    // Initialize 'children' only if 'isDirectory' is true
    init(name: String, path: String, isDirectory: Bool, children: [CustomFile]? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = isDirectory ? children : nil
    }
}
