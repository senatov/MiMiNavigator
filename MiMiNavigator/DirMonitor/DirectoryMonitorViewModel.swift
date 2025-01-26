//  DirectoryMonitorViewModel.swift
//  Directory Monitoring View Model Utility
//
//  Created by Iakov Senatov on 23.01.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
//  Dependencies: SwiftUI
//

/**
 Example Usage:
 struct ContentView: View {
 @StateObject private var viewModel = DirectoryMonitorViewModel(directoryPath: "/path/to/Sequoia")

 var body: some View {
 VStack {
 Text(viewModel.directoryChanged ? "Directory changed! 🚨" : "No changes ✅")
 .font(.title)
 .padding()

 Button("Reset") {
 viewModel.directoryChanged = false
 }
 }
 .animation(.default, value: viewModel.directoryChanged)
 }
 }
 */

//
//  DirectoryMonitorViewModel.swift
//  ViewModel working under @MainActor to ensure that SwiftUI observes
//  @Published properties safely.
//

import SwiftUI

@MainActor
final class DirectoryMonitorViewModel: ObservableObject {
    @Published var directoryChanged: Bool = false
    @Published var managerState: String = "No changes yet"

    // Low-level directory monitor
    private var monitor: DirectoryMonitor?
    // "Intermediate" layer of logic
    private var eventManager: DirectoryEventManager?

    init(directoryPath: String = "/path/to/Sequoia") {
        setup(directoryPath: directoryPath)
    }

    deinit {
    }

    // MARK: -
    private func setup(directoryPath: String) {
        log.info("setup()")
        let monitor = DirectoryMonitor(directoryPath: directoryPath)
        let manager = DirectoryEventManager()

        // When the monitor reports a new event
        monitor.onDirectoryChanged = { [weak manager, weak self] in
            // Pass it to the manager
            manager?.handleDirectoryChangeEvent()
            // Also immediately update the "directoryChanged" flag (if needed)
            self?.directoryChanged = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.directoryChanged = false
            }
        }
        // When the manager updates the state, notify the ViewModel
        manager.onStateUpdated = { [weak self] newState in
            self?.managerState = newState
        }
        // Save references
        self.monitor = monitor
        self.eventManager = manager
    }
}
