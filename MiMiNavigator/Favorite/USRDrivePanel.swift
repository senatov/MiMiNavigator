//
//  USRDrivePanel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 02.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

struct USRDrivePanel {
    // MARK: - Returns the URL of the user's Documents directory
    static var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the user's Caches directory
    static var cachesDirectory: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the Application Support directory
    static var applicationSupportDirectory: URL {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the Library directory
    static var libraryDirectory: URL {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the Downloads directory
    static var downloadsDirectory: URL {
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the Desktop directory
    static var desktopDirectory: URL {
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    // MARK: -  Returns the URL of the user's home directory
    static var homeDirectory: URL {
        return FileManager.default.homeDirectoryForCurrentUser
    }

    // MARK: - Returns the URL of the system's temporary directory
    static var systemTemporaryDirectory: URL {
        return FileManager.default.temporaryDirectory
    }

    /// Returns the URL of the user's Music directory
    static var musicDirectory: URL {
        return FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the user's Pictures directory
    static var picturesDirectory: URL {
        return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the user's Movies directory
    static var moviesDirectory: URL {
        return FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
    }

    // MARK: - Returns the URL of the iCloud Drive directory if available, logs error if unavailable
    static var iCloudDirectory: URL? {
        let cloudStorageURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage")
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cloudStorageURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            if let iCloudDrive = contents.first(where: { $0.lastPathComponent.hasPrefix("iCloudDrive-iCloudDrive") }) {
                return iCloudDrive
            } else {
                LogMan.log.error("iCloud Drive folder not found in ~/Library/CloudStorage")
            }
        } catch {
            LogMan.log.error("Failed to access CloudStorage for iCloud: \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Returns the URL of the OneDrive directory if available, logs error if unavailable
    static var oneDriveDirectory: URL? {
        let possiblePaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage/OneDrive"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("OneDrive"),
        ]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        LogMan.log.error("OneDrive directory not found. OneDrive may not be installed or is located in an unexpected directory.")
        return nil
    }

    // MARK: - Returns the URL of the Google Drive directory if available, logs error if unavailable
    static var googleDriveDirectory: URL? {
        if let googleDrivePath = GoogleDrvPath.googleDriveMyDrivePath,
            FileManager.default.fileExists(atPath: googleDrivePath.path)
        {
            return googleDrivePath
        } else {
            LogMan.log.error("Google Drive directory not found. Verify Google Drive is installed and accessible.")
            return nil
        }
    }

    // MARK: - Returns the URLs of all mounted network drives, logs error if unable to access
    static var networkDrives: [URL] {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return contents.filter { $0 != volumesURL.appendingPathComponent("Macintosh HD") }
        } catch {
            LogMan.log.error(
                "Failed to access network drives in /Volumes: \(error.localizedDescription). Ensure network drives are connected and accessible."
            )
            return []
        }
    }

    // MARK: - Returns an array containing the URLs of all available user directories, including iCloud, OneDrive, Google Drive, and network drives
    static var allDirectories: [URL] {
        var directories = [
            documentsDirectory,
            cachesDirectory,
            systemTemporaryDirectory,
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

func displayName(for directory: URL) -> String {
    let name = directory.lastPathComponent
    if name.contains("My Drive") {
        return "Google"
    } else if name.contains("iCloud") {
        return "iCloud"
    } else if name.contains("OneDrive") {
        return "OneDrive"
    } else if name.contains("ProtonDrive") {
        return "Proton"
    } else {
        return name
    }
}
