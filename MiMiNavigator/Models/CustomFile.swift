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
struct CustomFile: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [CustomFile]?

    // MARK: - Equatable Implementation
    static func == (lhs: CustomFile, rhs: CustomFile) -> Bool {
        lhs.path == rhs.path
    }

    // MARK: - Initialize 'children' only if 'isDirectory' is true
    init(name: String, path: String, isDirectory: Bool, children: [CustomFile]? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = isDirectory ? children ?? [] : nil
    }

    // MARK: - Debugging Log
    func logDetails() {
        log.debug("File: \(name), Path: \(path), Directory: \(isDirectory), Children: \(children?.count ?? 0)")
    }
}
