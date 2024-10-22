//
//  Untitled.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.10.24.
//
import SwiftUI

    /// Represents a file or folder that can optionally have child items to form a tree structure.
struct File: Identifiable {
    let id = UUID()

    var children: [File]? // Optional children to create tree structure
}
