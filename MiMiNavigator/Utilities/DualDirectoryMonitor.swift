
import Foundation
import Combine

class DualDirectoryMonitor: ObservableObject {
    @Published private(set) var leftFiles: [CustomFile] = []
    @Published private(set) var rightFiles: [CustomFile] = []
    private var fileMonitorQueue = DispatchQueue(label: "fileMonitorQueue")
    private var activeMonitors: [DispatchSourceFileSystemObject] = []
    private(set) var isMonitoring = false

    
    // Methods to update files
    func updateLeftFiles(newFiles: [CustomFile]) {
        leftFiles = newFiles
    }

    func updateRightFiles(newFiles: [CustomFile]) {
        rightFiles = newFiles
    }
    
    // Async function to start monitoring
    func startMonitoring() async {
        // Simulate monitoring work
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        } catch {
                // Handle the error if the sleep is interrupted
            print("Task.sleep was interrupted: \(error)")
        }
        // Example file update to simulate monitoring result
        updateLeftFiles(newFiles: [CustomFile(name: "SampleLeftFile")])
        updateRightFiles(newFiles: [CustomFile(name: "SampleRightFile")])
    }
    
    func stopMonitoring() async {
            // Реальный код остановки мониторинга
            // Закрытие всех запущенных наблюдателей директорий и освобождение ресурсов
            // Например:
        if isMonitoring {
            fileMonitorQueue.async {
                for monitor in self.activeMonitors {
                    monitor.cancel()
                }
                self.activeMonitors.removeAll()
            }
            isMonitoring = false
        }
    }
    
    
        // Метод для обновления leftFiles
    private func updateLeftFiles(newFiles: [CustomFile]) {
        DispatchQueue.main.async {
            self.leftFiles = newFiles
        }
    }
    
        // Метод для обновления rightFiles
    private func updateRightFiles(newFiles: [CustomFile]) {
        DispatchQueue.main.async {
            self.rightFiles = newFiles
        }
    }
    
        // Метод для извлечения файлов из директории
    private func fetchFilesFromDirectory(_ path: String) -> [CustomFile] {
            // Логика для извлечения массива CustomFile из указанной директории
        return []
    }
}
