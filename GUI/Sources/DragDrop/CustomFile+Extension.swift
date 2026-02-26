//
// CustomFile+UTType.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
// Transferable conformance moved to FileModelKit/CustomFile+Transferable.swift

import UniformTypeIdentifiers

// MARK: - Custom UTType for internal drag-drop (kept for future use)
extension UTType {
    static let mimiNavigatorFile = UTType(exportedAs: "com.senatov.miminavigator.file")
}
