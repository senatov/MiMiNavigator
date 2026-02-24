//
// CustomFileTransferable.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI
import FileModelKit
import UniformTypeIdentifiers

// MARK: - Make CustomFile draggable via Transferable protocol
extension CustomFile: Transferable {

    public static var transferRepresentation: some TransferRepresentation {
        // Export file URL only. Works for:
        // - External apps (Finder, Terminal) — receive a real file reference
        // - Internal MiMi drops — .dropDestination(for: URL.self) decodes back to CustomFile
        // No CodableRepresentation — it leaked JSON blobs to external apps.
        ProxyRepresentation(exporting: \.urlValue)
    }
}

// MARK: - Custom UTType for internal drag-drop (kept for future use)
extension UTType {
    static let mimiNavigatorFile = UTType(exportedAs: "com.senatov.miminavigator.file")
}
