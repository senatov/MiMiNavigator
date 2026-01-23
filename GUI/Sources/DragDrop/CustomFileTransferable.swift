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
        // Primary: File representation using .item for generic files
        FileRepresentation(exportedContentType: .item) { file in
            // Return the file URL for dragging
            SentTransferredFile(file.urlValue)
        }
        
        // Import representation for dropping files
        FileRepresentation(importedContentType: .item) { received in
            CustomFile(path: received.file.path)
        }
        
        // Fallback: Codable representation for internal transfers
        CodableRepresentation(contentType: .mimiNavigatorFile)
    }
}

// MARK: - Custom UTType for internal drag-drop
extension UTType {
    static let mimiNavigatorFile = UTType(exportedAs: "com.senatov.miminavigator.file")
}
