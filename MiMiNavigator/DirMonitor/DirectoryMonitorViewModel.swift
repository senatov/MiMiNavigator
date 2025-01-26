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
//  ViewModel, работающий на @MainActor, чтобы SwiftUI безопасно
//  наблюдал @Published-свойства
//

import SwiftUI

@MainActor
final class DirectoryMonitorViewModel: ObservableObject {
    @Published var directoryChanged: Bool = false
    @Published var managerState: String = "No changes yet"

    // "Низкоуровневый" монитор
    private var monitor: DirectoryMonitor?
    // "Средний" слой логики
    private var eventManager: DirectoryEventManager?

    init(directoryPath: String = "/path/to/Sequoia") {
        setup(directoryPath: directoryPath)
    }

    deinit {
    }

    private func setup(directoryPath: String) {
        let monitor = DirectoryMonitor(directoryPath: directoryPath)
        let manager = DirectoryEventManager()

        // Когда монитор сообщает о новом событии
        monitor.onDirectoryChanged = { [weak manager, weak self] in
            // Пробрасываем в менеджер
            manager?.handleDirectoryChangeEvent()

            // Также сразу меняем флаг "directoryChanged" (если надо)
            self?.directoryChanged = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.directoryChanged = false
            }
        }

        // Когда менеджер меняет состояние, сообщаем это во ViewModel
        manager.onStateUpdated = { [weak self] newState in
            self?.managerState = newState
        }

        // Сохраняем ссылки
        self.monitor = monitor
        self.eventManager = manager
    }
}
