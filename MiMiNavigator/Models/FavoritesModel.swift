//
//  FavoritesModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 02.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

extension FileManager {
    /// Returns the URL of the user's Documents directory
    var documentsDirectory: URL {
        return urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the user's Caches directory
    var cachesDirectory: URL {
        return urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the Application Support directory
    var applicationSupportDirectory: URL {
        return urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the Library directory
    var libraryDirectory: URL {
        return urls(for: .libraryDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the Downloads directory
    var downloadsDirectory: URL {
        return urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the Desktop directory
    var desktopDirectory: URL {
        return urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the user's home directory
    var homeDirectory: URL {
        return homeDirectoryForCurrentUser
    }

    /// Returns the URL of the system's temporary directory
    var systemTemporaryDirectory: URL {
        return FileManager.default.temporaryDirectory
    }

    /// Returns the URL of the user's Music directory
    var musicDirectory: URL {
        return urls(for: .musicDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the user's Pictures directory
    var picturesDirectory: URL {
        return urls(for: .picturesDirectory, in: .userDomainMask).first!
    }

    /// Returns the URL of the user's Movies directory
    var moviesDirectory: URL {
        return urls(for: .moviesDirectory, in: .userDomainMask).first!
    }

    /// Returns an array containing the URLs of all available user directories
    var allDirectories: [URL] {
        return [
            documentsDirectory,
            cachesDirectory,
            FileManager.default.temporaryDirectory, // Use the built-in temporary directory here
            applicationSupportDirectory,
            libraryDirectory,
            downloadsDirectory,
            desktopDirectory,
            homeDirectory,
            systemTemporaryDirectory,
            musicDirectory,
            picturesDirectory,
            moviesDirectory,
        ]
    }
}
