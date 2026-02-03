//
// CustomFileTransferable.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Make CustomFile draggable via Transferable protocol
extension CustomFile: Transferable {
    
    public static var transferRepresentation: some TransferRepresentation {
        // PRIMARY: Codable representation for internal MiMiNavigator transfers
        // This is the key fix - CodableRepresentation preserves the original file path
        // instead of creating temporary copies in sandbox cache
        CodableRepresentation(contentType: .mimiNavigatorFile)
        
        // SECONDARY: File representation for dragging TO external apps
        // Note: This is export-only, we don't use FileRepresentation for import
        // because it creates temp copies which breaks move operations
        FileRepresentation(exportedContentType: .item) { @concurrent file in
            SentTransferredFile(file.urlValue)
        }
    }
}

// MARK: - Custom UTType for internal drag-drop
extension UTType {
    static let mimiNavigatorFile = UTType(exportedAs: "com.senatov.miminavigator.file")
}
