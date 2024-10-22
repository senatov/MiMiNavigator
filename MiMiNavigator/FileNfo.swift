//
//  Untitled.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.10.24.
//
import SwiftUI

    /// Represents a file or folder that can optionally have child items to form a tree structure.
struct FileNfo: Identifiable {
    let id = UUID()
    var children: [FileNfo]? // Optional children to create tree structure
}
