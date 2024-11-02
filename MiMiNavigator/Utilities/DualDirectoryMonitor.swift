//
//  DualDirectoryMonitor.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

class DualDirectoryMonitor: ObservableObject {
    @Published var leftFiles: [CustomFile] = []
    @Published var rightFiles: [CustomFile] = []

    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let leftDirectory: URL
    private let rightDirectory: URL

    // MARK: - -

    init(leftDirectoryPath: String, rightDirectoryPath: String) {
        leftDirectory = URL(fileURLWithPath: leftDirectoryPath)
        rightDirectory = URL(fileURLWithPath: rightDirectoryPath)
        startMonitoring()
    }

    // MARK: - - Start monitoring both directories

    private func startMonitoring() {
        // Timer for left directory
        leftTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        leftTimer?.schedule(deadline: .now(), repeating: 1.0) // Every 1 second
        leftTimer?.setEventHandler { [weak self] in
            self?.scanDirectory(at: self?.leftDirectory, for: .left)
        }
        leftTimer?.resume()

        // Timer for right directory
        rightTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        rightTimer?.schedule(deadline: .now(), repeating: 1.0)
        rightTimer?.setEventHandler { [weak self] in
            self?.scanDirectory(at: self?.rightDirectory, for: .right)
        }
        rightTimer?.resume()
    }

    // MARK: - - Stop monitoring both directories

    func stopMonitoring() {
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    // Scans directory and updates the appropriate file collection
    private func scanDirectory(at url: URL?, for side: DirectorySide) {
        guard let url = url else { return }
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let files = contents.map { fileURL in
                CustomFile(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    isDirectory: (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                )
            }

            DispatchQueue.main.async {
                if side == .left {
                    self.leftFiles = files
                } else {
                    self.rightFiles = files
                }
            }
        } catch {
            print("Error reading directory contents: \(error)")
        }
    }

    deinit {
        stopMonitoring()
    }

    enum DirectorySide {
        case left
        case right
    }
}
