import Foundation

struct FavTreePanel {
        // MARK: - Returns the URL of the user's Documents directory
    static var documentsDirectory: URL {
        return safeSystemDirectory(for: .documentDirectory, label: "documentDirectory")
    }
    
        // MARK: - Returns the URL of the user's Caches directory
    static var cachesDirectory: URL {
        return safeSystemDirectory(for: .cachesDirectory, label: "cachesDirectory")
    }
    
        // MARK: - Returns the URL of the Application Support directory
    static var applicationSupportDirectory: URL {
        return safeSystemDirectory(for: .applicationSupportDirectory, label: "applicationSupportDirectory")
    }
    
        // MARK: - Returns the URL of the Library directory
    static var libraryDirectory: URL {
        return safeSystemDirectory(for: .libraryDirectory, label: "libraryDirectory")
    }
    
        // MARK: - Returns the URL of the Downloads directory
    static var downloadsDirectory: URL {
        return safeSystemDirectory(for: .downloadsDirectory, label: "downloadsDirectory")
    }
    
        // MARK: - Returns the URL of the Desktop directory
    static var desktopDirectory: URL {
        return safeSystemDirectory(for: .desktopDirectory, label: "desktopDirectory")
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
        return safeSystemDirectory(for: .musicDirectory, label: "musicDirectory")
    }
    
        // MARK: - Returns the URL of the user's Pictures directory
    static var picturesDirectory: URL {
        return safeSystemDirectory(for: .picturesDirectory, label: "picturesDirectory")
    }
    
        // MARK: -
    static var trashDirectory: URL {
        return safeSystemDirectory(for: .trashDirectory, label: "trashDirectory")
    }
    
        // MARK: - Returns the URL of the user's Movies directory
    static var moviesDirectory: URL {
        return safeSystemDirectory(for: .moviesDirectory, label: "moviesDirectory")
    }
    
        // MARK: -
    private static func safeSystemDirectory(for directory: FileManager.SearchPathDirectory, label: String) -> URL {
        guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            LogMan.log.error("Failed to get \(label)")
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return url
    }
    
        // MARK: - Returns the URL of the iCloud Drive directory if available, logs error if unavailable
    static var iCloudDirectory: URL? {
        return cloudStorageDirectory(containing: "iCloudDrive-iCloudDrive", startsWith: true)
    }
    
        // MARK: - Returns the URL of the OneDrive directory if available, logs error if unavailable
    static var oneDriveDirectory: URL? {
        return cloudStorageDirectory(containing: "OneDrive")
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
        let networkKey = URLResourceKey(rawValue: "NSURLVolumeIsNetworkKey")
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: volumesURL,
                includingPropertiesForKeys: [networkKey],
                options: .skipsHiddenFiles
            )
            return contents.filter {
                guard let values = try? $0.resourceValues(forKeys: [networkKey]),
                      let isNetwork = values.allValues[networkKey] as? Bool else {
                    return false
                }
                return isNetwork
            }
        } catch {
            LogMan.log.error("Failed to access network drives in /Volumes: \(error.localizedDescription). Ensure network drives are connected and accessible.")
            return []
        }
    }
    
        // MARK: - Returns an array containing the URLs of all available user directories, including iCloud, OneDrive, Google Drive, and network drives
    static var allDirectories: [URL] {
        var directories = [
            applicationSupportDirectory,
            cachesDirectory,
            desktopDirectory,
            documentsDirectory,
            downloadsDirectory,
            homeDirectory,
            libraryDirectory,
            moviesDirectory,
            musicDirectory,
            picturesDirectory,
            systemTemporaryDirectory,
            trashDirectory,
        ]
        
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
    
    private static func cloudStorageDirectory(containing name: String, startsWith: Bool = false) -> URL? {
        let cloudStorageURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage")
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cloudStorageURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            let match = contents.first(where: {
                startsWith ? $0.lastPathComponent.hasPrefix(name) : $0.lastPathComponent.contains(name)
            })
            if match == nil {
                LogMan.log.error("\(name) folder not found in ~/Library/CloudStorage")
            }
            return match
        } catch {
            LogMan.log.error("Failed to access CloudStorage for \(name): \(error.localizedDescription)")
            return nil
        }
    }
}
