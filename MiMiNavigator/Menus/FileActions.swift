//
//  FileActions.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import AppKit

enum FileActions {

    static func view(_ file: CustomFile) {
        NSWorkspace.shared.openFile(file.fullPath)
    }

    static func edit(_ file: CustomFile) {
        NSWorkspace.shared.openFile(file.fullPath, withApplication: "TextEdit")
    }

    static func delete(_ file: CustomFile) {
        do {
            try FileManager.default.trashItem(at: file.urlValue, resultingItemURL: nil)
        } catch {
            print("❌ Failed to delete: \(error.localizedDescription)")
        }
    }
}
