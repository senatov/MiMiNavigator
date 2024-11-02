//
//  Untitled.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 02.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import os.log

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
            os_log("iCloud directory not available", log: .default, type: .error)
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
        os_log("OneDrive directory not found in expected paths", log: .default, type: .error)
        return nil
    }

    /// Returns the URL of the Google Drive directory if available, logs error if unavailable
    var googleDriveDirectory: URL? {
        let googleDrivePath = homeDirectoryForCurrentUser.appendingPathComponent("Google Drive")
        if fileExists(atPath: googleDrivePath.path) {
            return googleDrivePath
        } else {
            os_log("Google Drive directory not found", log: .default, type: .error)
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
            os_log("Failed to access network drives: %{public}@", log: .default, type: .error, error.localizedDescription)
            return []
        }
    }

    /// Returns an array containing the URLs of all available user directories, including iCloud, OneDrive, Google Drive, and network drives
    public var allDirectories: [URL] {
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
