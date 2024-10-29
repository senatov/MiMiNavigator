//
//  DualDirectoryMonitor.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//

import Foundation
import SwiftUI

// MARK: - DualDirectoryMonitor

class DualDirectoryMonitor: ObservableObject {
    @Published var leftFiles: [CustomFile] = []
    @Published var rightFiles: [CustomFile] = []

    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let leftDirectory: URL
    private let rightDirectory: URL

    // MARK: - Initializer

    init(leftDirectory: URL, rightDirectory: URL) {
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory
        startMonitoring()
    }

    // MARK: - Start Monitoring

    private func startMonitoring() {
        leftTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        leftTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        leftTimer?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.leftFiles = self?.scanDirectory(at: self?.leftDirectory) ?? []
            }
        }
        leftTimer?.resume()

        rightTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        rightTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        rightTimer?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.rightFiles = self?.scanDirectory(at: self?.rightDirectory) ?? []
            }
        }
        rightTimer?.resume()
    }

    // MARK: - Stop Monitoring

    func stopMonitoring() {
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    // MARK: - Scan Directory

    private func scanDirectory(at url: URL?) -> [CustomFile] {
        guard let url = url else { return [] }
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return contents.map { fileURL in
                CustomFile(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    isDirectory: (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                )
            }
        } catch {
            print("Error reading directory contents: \(error)")
            return []
        }
    }

    // MARK: - Deinitializer

    deinit {
        stopMonitoring()
    }

    // MARK: - DirectorySide Enum

    enum DirectorySide {
        case left
        case right
    }
}
