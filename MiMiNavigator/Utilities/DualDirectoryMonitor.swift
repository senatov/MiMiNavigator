//
//  DualDirectoryMonitor.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftUI

actor DualDirectoryMonitor: ObservableObject {
    @MainActor @Published private(set) var leftFiles: [CustomFile] = []
    @MainActor @Published private(set) var rightFiles: [CustomFile] = []
    
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?
    private let leftDirectory: URL
    private let rightDirectory: URL
    
        // MARK: - Initializer
    
    init(leftDirectory: URL, rightDirectory: URL) {
        self.leftDirectory = leftDirectory
        self.rightDirectory = rightDirectory
    }
    
        // MARK: - Directory Monitoring Functions
    
    func startMonitoring() {
            // Start monitoring left directory every second
        print("Starting directory monitoring")
        leftTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        leftTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        leftTimer?.setEventHandler {
            Task { [unowned self] in
                await self.refreshFiles(for: .left)
            }
        }
        leftTimer?.resume()
        
            // Start monitoring right directory every second
        rightTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        rightTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        rightTimer?.setEventHandler {
            Task { [unowned self] in
                await self.refreshFiles(for: .right)
            }
        }
        rightTimer?.resume()
    }
    
    func stopMonitoring() {
        print("Stop directory monitoring")
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
    }
    
        // MARK: - Helper Functions
    
    private enum DirectorySide {
        case left, right
    }
    
    private func refreshFiles(for side: DirectorySide) async {
        let directoryURL = side == .left ? leftDirectory : rightDirectory
        let files = fetchFiles(in: directoryURL)
        
            // Update files based on the directory side on the main actor
        await MainActor.run {
            switch side {
                case .left:
                    self.leftFiles = files
                case .right:
                    self.rightFiles = files
            }
        }
    }
    
    private func fetchFiles(in directory: URL) -> [CustomFile] {
            // Logic to fetch files from directory
        return []
    }
}
