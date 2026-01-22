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
        // Primary: File URL representation for system interop
        FileRepresentation(contentType: .fileURL) { file in
            SentTransferredFile(file.urlValue)
        } importing: { @concurrent received in
            let url = received.file
            return CustomFile(path: url.path)
        }
        
        // Fallback: Codable representation for internal transfers
        CodableRepresentation(contentType: .mimiNavigatorFile)
    }
}

// MARK: - Custom UTType for internal drag-drop
extension UTType {
    static let mimiNavigatorFile = UTType(exportedAs: "com.senatov.miminavigator.file")
}
