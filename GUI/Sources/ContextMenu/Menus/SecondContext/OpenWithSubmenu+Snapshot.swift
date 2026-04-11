//
//  OpenWithSubmenu+Snapshot.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
import AppKit
import FileModelKit
import SwiftUI

// MARK: - Snapshot
extension OpenWithSubmenu {
    struct Snapshot {
        let fileName: String
        let fileURL: URL
        let fileExtension: String
        let apps: [AppInfo]
        let menuID: String
        let debugSignature: String

        init(file: CustomFile, apps: [AppInfo]) {
            fileName = file.nameStr
            fileURL = file.urlValue
            fileExtension = file.fileExtension
            self.apps = apps
            menuID = Self.makeMenuID(fileURL: fileURL, apps: apps)
            debugSignature = Self.makeDebugSignature(fileName: fileName, menuID: menuID, apps: apps)
        }

        private static func makeMenuID(fileURL: URL, apps: [AppInfo]) -> String {
            let bundles = apps.map(\.bundleIdentifier).joined(separator: ",")
            return "openwith|\(fileURL.path)|\(bundles)"
        }

        private static func makeDebugSignature(fileName: String, menuID: String, apps: [AppInfo]) -> String {
            "menuID='\(menuID)' file='\(fileName)' apps=\(apps.count)"
        }
    }
}
