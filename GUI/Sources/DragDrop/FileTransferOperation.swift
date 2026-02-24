//
// FileTransferOperation.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation
import FileModelKit

/// Represents a pending file transfer operation
struct FileTransferOperation: Identifiable, Equatable {
    let id = UUID()
    let sourceFiles: [CustomFile]
    let destinationPath: URL
    let sourcePanelSide: PanelSide?
    
    /// Human-readable description of items being transferred
    var itemsDescription: String {
        if sourceFiles.count == 1 {
            let file = sourceFiles[0]
            let type = file.isDirectory ? "folder" : "file"
            return "\"\(file.nameStr)\" (\(type))"
        } else {
            let folders = sourceFiles.filter { $0.isDirectory || $0.isSymbolicDirectory }.count
            let files = sourceFiles.count - folders
            var parts: [String] = []
            if folders > 0 { parts.append("\(folders) folder\(folders == 1 ? "" : "s")") }
            if files > 0 { parts.append("\(files) file\(files == 1 ? "" : "s")") }
            return parts.joined(separator: " and ")
        }
    }
    
    /// Destination folder name
    var destinationName: String {
        destinationPath.lastPathComponent
    }
}

/// Result of the confirmation dialog
enum FileTransferAction: Equatable {
    case move
    case copy
    case abort
}
