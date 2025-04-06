//
//  FavoritesModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 02.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

class FavoritesModel {
    // Array to hold favorite directory URLs
    var favoriteDirectories: [URL] = []

    init() {
        setupFavoriteDirectories()
    }

    // MARK: -  Sets up default favorite directories, including iCloud, OneDrive, Google Drive, and network drives if available
    private func setupFavoriteDirectories() {
        favoriteDirectories.append(contentsOf: [
            USRDrivePanel.documentsDirectory,
            USRDrivePanel.cachesDirectory,
            USRDrivePanel.applicationSupportDirectory,
            USRDrivePanel.libraryDirectory,
            USRDrivePanel.downloadsDirectory,
            USRDrivePanel.desktopDirectory,
            USRDrivePanel.homeDirectory,
            USRDrivePanel.musicDirectory,
            USRDrivePanel.picturesDirectory,
            USRDrivePanel.moviesDirectory,
            USRDrivePanel.systemTemporaryDirectory,
        ])

        // Optionally add iCloud, OneDrive, Google Drive, and network drives if available
        if let iCloud = USRDrivePanel.iCloudDirectory {
            favoriteDirectories.append(iCloud)
        }

        if let oneDrive = USRDrivePanel.oneDriveDirectory {
            favoriteDirectories.append(oneDrive)
        }

        if let googleDrive = USRDrivePanel.googleDriveDirectory {
            favoriteDirectories.append(googleDrive)
        }
        favoriteDirectories.append(contentsOf: USRDrivePanel.networkDrives)
    }
}
