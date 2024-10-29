//
//  DualDirectoryMonitor.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - -

class DualDirectoryMonitor: ObservableObject {
    @Published var leftFiles: [CustomFile] = []
    @Published var rightFiles: [CustomFile] = []

    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let leftDirectory: URL
    private let rightDirectory: URL

    init(leftDirectory: URL, rightDirectory: URL) {
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory
        startMonitoring()
    }

    // MARK: - -

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

    // MARK: - -

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
        // Implement directory scanning logic
        return []
    }

    // MARK: - -

    init(leftDirectoryPath: String, rightDirectoryPath: String) {
        leftDirectory = URL(fileURLWithPath: leftDirectoryPath)
        rightDirectory = URL(fileURLWithPath: rightDirectoryPath)
        startMonitoring()
    }

    // MARK: - -  Stop monitoring both directories

    func stopMonitoring() {
        print("Executing stopMonitoring") // Log for method tracking
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }

    // MARK: - -  Scans directory and updates the appropriate file collection

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

    // MARK: - -

    enum DirectorySide {
        case left
        case right
    }
}
