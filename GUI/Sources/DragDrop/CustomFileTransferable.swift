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
            // Start security-scoped access before sending
            _ = file.urlValue.startAccessingSecurityScopedResource()
            return SentTransferredFile(file.urlValue)
        } importing: { @concurrent received in
            let url = received.file
            // Start security-scoped access for received file
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
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
