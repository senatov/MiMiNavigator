//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import SwiftData
import SwiftUI
import SwiftyBeaver

let log = SwiftyBeaver.self

@main
struct MiMiNavigatorApp: App {

    // MARK: -
    init() {
        LogMan.initializeLogging()
    }

    // MARK: -
    private func cleanUpOldZipFiles(in directory: URL) throws {
        LogMan.log.debug("cleanUpOldZipFiles()")
        let fileManager = FileManager.default
        let zipFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            .filter { $0.pathExtension == "zip" }
            .sorted { (file1: URL, file2: URL) in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
        let filesToDelete = zipFiles.dropFirst(3)
        for file in filesToDelete {
            try fileManager.removeItem(at: file)
            LogMan.log.debug("Deleted old zip file: \(file.lastPathComponent)")
        }
    }

    // MARK: -
    private func cleanUpOldLogs(in directory: URL) throws {
        LogMan.log.debug("cleanUpOldLogs()")
        let fileManager = FileManager.default
        let twoHourAgo =
            Calendar.current.date(
                byAdding: .hour,
                value: -2,
                to: Date()
            ) ?? Date.distantPast
        let logFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            .filter { $0.pathExtension == "log" }
        for logFile in logFiles {
            let creationDate = try logFile.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            if creationDate < twoHourAgo {
                try fileManager.removeItem(at: logFile)
                LogMan.log.debug("Deleted old log file: \(logFile.lastPathComponent)")
            }
        }
    }

    // MARK: -
    var sharedModelContainer: ModelContainer = {
        LogMan.log.debug(" ---- BEGIN ----")
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: -
    var body: some Scene {
        WindowGroup {
            VStack {
                TotalCommanderResizableView()
                ConsoleCurrPath()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
