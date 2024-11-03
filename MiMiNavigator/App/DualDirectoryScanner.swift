
import Combine
import Foundation

actor DualDirectoryScanner: ObservableObject {
    private(set) var leftFiles: [CustomFile] = []
    private(set) var rightFiles: [CustomFile] = []

    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let leftDirectory: URL
    private let rightDirectory: URL

    // MARK: -

    init(leftDirectory: URL, rightDirectory: URL) {
        log.debug("DualDirectoryScanner initialized.")
        self.leftDirectory = leftDirectory
        log.debug("left directory: \(leftDirectory.path)")
        self.rightDirectory = rightDirectory
        log.debug("right directory: \(rightDirectory.path)")

        // Start monitoring in an asynchronous task to handle actor isolation
        Task {
            await startMonitoring()
        }
    }

    // MARK: - Starts monitoring both directories with a 1-second refresh interval.

    func startMonitoring() {
        // Setup left directory timer
        leftTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        leftTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        leftTimer?.setEventHandler { [weak self] in
            Task.detached { [weak self] in
                await self?.refreshFiles(for: .left)
            }
        }
        leftTimer?.resume()
        // Setup right directory timer
        rightTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        rightTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        rightTimer?.setEventHandler { [weak self] in
            Task.detached { [weak self] in
                await self?.refreshFiles(for: .right)
            }
        }
        rightTimer?.resume()
        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize one or both timers.")
        }
    }

    // MARK: - Stops monitoring both directories and cancels active timers.

    func stopMonitoring() {
        log.debug("Stopping directory monitoring.")
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    // MARK: - Getters for Files

    func getLeftFiles() -> [CustomFile] {
        return leftFiles
    }

    // MARK: -

    func getRightFiles() -> [CustomFile] {
        return rightFiles
    }

    // MARK: - Directory Monitoring

    private enum DirectorySide {
        case left, right
    }

    // MARK: - Refreshes file list for the specified directory side.Parameter side: The directory side to refresh (.left or .right).

    private func refreshFiles(for side: DirectorySide) async {
        log.debug("Refreshing files for \(side == .left ? "left" : "right") directory.")
        let directoryURL = (side == .left) ? leftDirectory : rightDirectory
        let files = scanDirectory(at: directoryURL)
        switch side {
        case .left:
            leftFiles = files
        case .right:
            rightFiles = files
        }
    }

    // MARK: - Directory Scanning

    /// Scans the specified directory URL for files and directories.
    /// - Parameter url: The URL of the directory to scan.
    /// - Returns: An array of `CustomFile` objects representing the contents of the directory.
    private func scanDirectory(at url: URL?) -> [CustomFile] {
        log.debug("scanDirectory() called for URL: \(url?.path ?? "nil")")
        // Validate the URL
        guard let url = url else {
            log.error("Invalid directory URL: URL is nil.")
            return []
        }
        let fileManager = FileManager.default
        var customFiles: [CustomFile] = []
        do {
            // Attempt to retrieve directory contents
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            for fileURL in contents {
                // Safely retrieve isDirectory property for each item
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                // Create and add a CustomFile object
                let customFile = CustomFile(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    isDirectory: isDirectory
                )
                customFiles.append(customFile)
            }
        } catch {
            // Log any error encountered during directory scan
            log.error("Failed to scan directory at \(url.path): \(error.localizedDescription)")
        }
        return customFiles
    }
}
