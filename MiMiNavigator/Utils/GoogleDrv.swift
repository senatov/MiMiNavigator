    //
    //  GoogleDrv.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 06.04.25.
    //  Copyright © 2025 Senatov. All rights reserved.
    //


import Foundation

struct GoogleDrvPath {
        /// Возвращает путь к ~/Library/CloudStorage/GoogleDrive-*/My Drive без параметров
    static var googleDriveMyDrivePath: URL? {
        let cloudStorageURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage")

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cloudStorageURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

            if let googleDriveFolder = contents.first(where: { $0.lastPathComponent.hasPrefix("GoogleDrive-") }) {
                let myDrivePath = googleDriveFolder.appendingPathComponent("My Drive")
                if FileManager.default.fileExists(atPath: myDrivePath.path) {
                    return myDrivePath
                } else {
                    log.error("Google Drive 'My Drive' folder not found in \(googleDriveFolder.path)")
                }
            } else {
                log.error("No Google Drive folder found in ~/Library/CloudStorage")
            }
        } catch {
            log.error("Unable to access CloudStorage directory: \(error.localizedDescription)")
        }

        return nil
    }
}
