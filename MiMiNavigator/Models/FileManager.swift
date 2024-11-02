//
//  Untitled.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 02.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftyBeaver

extension FileManager {
    // MARK: - - Returns the URL of the user's Documents directory

    var documentsDirectory: URL {
        return urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - - Returns the URL of the user's Caches directory

    var cachesDirectory: URL {
        return urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    // MARK: - - Returns the URL of the Application Support directory

    var applicationSupportDirectory: URL {
        return urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    // MARK: - - Returns the URL of the Library directory

    var libraryDirectory: URL {
        return urls(for: .libraryDirectory, in: .userDomainMask).first!
    }

    // MARK: - - Returns the URL of the Downloads directory

    var downloadsDirectory: URL {
        return urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    // MARK: - - Returns the URL of the Desktop directory

    var desktopDirectory: URL {
        return urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    // MARK: - - Returns the URL of the user's home directory

    var homeDirectory: URL {
        return homeDirectoryForCurrentUser
    }

    // MARK: - - Returns the URL of the system's temporary directory

    var systemTemporaryDirectory: URL {
        return temporaryDirectory
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

    /// Returns the URL of the iCloud Drive directory if available, logs error if unavailable
    var iCloudDirectory: URL? {
        guard let iCloudURL = url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            log.error("iCloud directory not available. Ensure iCloud is enabled and accessible.")
            return nil
        }
        return iCloudURL
    }

    /// Returns the URL of the OneDrive directory if available, logs error if unavailable
    var oneDriveDirectory: URL? {
        let possiblePaths = [
            homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage/OneDrive"),
            homeDirectoryForCurrentUser.appendingPathComponent("OneDrive"),
        ]
        for path in possiblePaths {
            if fileExists(atPath: path.path) {
                return path
            }
        }
        log.error("OneDrive directory not found. OneDrive may not be installed or is located in an unexpected directory.")
        return nil
    }

    /// Returns the URL of the Google Drive directory if available, logs error if unavailable
    var googleDriveDirectory: URL? {
        let googleDrivePath = homeDirectoryForCurrentUser.appendingPathComponent("Google Drive")
        if fileExists(atPath: googleDrivePath.path) {
            return googleDrivePath
        } else {
            log.error("Google Drive directory not found. Verify Google Drive is installed and accessible.")
            return nil
        }
    }

    /// Returns the URLs of all mounted network drives, logs error if unable to access
    var networkDrives: [URL] {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        do {
            let contents = try contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return contents.filter { $0 != volumesURL.appendingPathComponent("Macintosh HD") }
        } catch {
            log.error("Failed to access network drives in /Volumes: \(error.localizedDescription). Ensure network drives are connected and accessible.")
            return []
        }
    }

    /// Returns an array containing the URLs of all available user directories, including iCloud, OneDrive, Google Drive, and network drives
    var allDirectories: [URL] {
        var directories = [
            documentsDirectory,
            cachesDirectory,
            temporaryDirectory,
            applicationSupportDirectory,
            libraryDirectory,
            downloadsDirectory,
            desktopDirectory,
            homeDirectory,
            musicDirectory,
            picturesDirectory,
            moviesDirectory,
        ]

        // Optionally add iCloud, OneDrive, Google Drive, and network drives if available
        if let iCloud = iCloudDirectory {
            directories.append(iCloud)
        }

        if let oneDrive = oneDriveDirectory {
            directories.append(oneDrive)
        }

        if let googleDrive = googleDriveDirectory {
            directories.append(googleDrive)
        }

        directories.append(contentsOf: networkDrives)

        return directories
    }
}
