//  DirectoryMonitorViewModel.swift
//  Directory Monitoring View Model Utility
//
//  Created by Iakov Senatov on 23.01.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
//  Dependencies: SwiftUI
//

/**

 struct ContentView: View {
 @StateObject private var viewModel = DirectoryMonitorViewModel(directoryPath: "/path/to/Sequoia")

 var body: some View {
 VStack {
 Text(viewModel.directoryChanged ? "Директория изменилась! 🚨" : "Нет изменений ✅")
 .font(.title)
 .padding()

 Button("Сбросить") {
 viewModel.directoryChanged = false
 }
 }
 .animation(.default, value: viewModel.directoryChanged)
 }
 }

 */

import SwiftUI

@MainActor
final class DirectoryMonitorViewModel: ObservableObject {
    @Published var directoryChanged = false
    private var monitor: DirectoryMonitor?

    init(directoryPath: String = "/path/to/Sequoia") {
        startMonitoring(directoryPath: directoryPath)
    }

    private func startMonitoring(directoryPath: String) {
        monitor = DirectoryMonitor(directoryPath: directoryPath)
        monitor?.onDirectoryChanged = { [weak self] in
            guard let self = self else { return }  // Защита от уже освобождённого self
            Task { @MainActor in
                self.directoryChanged = true
                // Автоматический сброс флага (опционально)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.directoryChanged = false
                }
            }
        }
    }

    deinit {
        Task { @MainActor in
            monitor?.stopMonitoring()
        }
        monitor = nil  // Явное обнуление для освобождения объекта
    }
}
