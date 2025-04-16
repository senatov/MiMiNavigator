//
//  FavoritesModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 02.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

class FavModel {
    // Array to hold favorite directory URLs
    var favoriteDirectories: [URL] = []

    init() {
        setupFavoriteDirectories()
    }

    // MARK: -  Sets up default favorite directories, including iCloud, OneDrive, Google Drive, and network drives if available
    private func setupFavoriteDirectories() {
        let fileManager = FileManager.default
        // Adding standard directories
        favoriteDirectories.append(contentsOf: [
            fileManager.documentsDirectory,
            fileManager.cachesDirectory,
            fileManager.temporaryDirectory,
            fileManager.applicationSupportDirectory,
            fileManager.libraryDirectory,
            fileManager.downloadsDirectory,
            fileManager.desktopDirectory,
            fileManager.homeDirectory,
            fileManager.musicDirectory,
            fileManager.picturesDirectory,
            fileManager.moviesDirectory,
        ])

        // Optionally add iCloud, OneDrive, Google Drive, and network drives if available
        if let iCloud = fileManager.iCloudDirectory {
            favoriteDirectories.append(iCloud)
        }

        if let oneDrive = fileManager.oneDriveDirectory {
            favoriteDirectories.append(oneDrive)
        }

        if let googleDrive = fileManager.googleDriveDirectory {
            favoriteDirectories.append(googleDrive)
        }
        favoriteDirectories.append(contentsOf: fileManager.networkDrives)
    }
}
