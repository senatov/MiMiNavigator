//
//  DirectoryMonitor.swift
//  Directory Monitoring Utility
//
//  Created by Iakov Senatov on 23.01.25.
//  Description: Простейший вариант класса, следящего за изменением даты модификации директории.
//  Без использования async/await, @MainActor или actor.
//
//  Dependencies: Foundation, Combine
//

import Combine
import Foundation

/// Класс, мониторящий директорию с помощью таймера.
/// Не отмечен как actor или @MainActor, чтобы избежать ошибок изоляции.
final class DirectoryMonitor: ObservableObject {
    // Таймер для периодической проверки директории
    private var timer: Timer?
    // Путь к директории, за которой следим
    private let directoryURL: URL
    // Храним дату последнего изменения
    @Published private var lastModificationDate: Date?
    // Колбэк, вызываемый при изменении директории
    var onDirectoryChanged: (() -> Void)?
    /// Инициализатор, принимающий строку пути к директории.
    /// После инициализации сразу запускаем мониторинг.
    init(directoryPath: String) {
        self.directoryURL = URL(fileURLWithPath: directoryPath)
        startMonitoring()
    }

    /// При уничтожении объекта — останавливаем таймер.
    deinit {
        stopMonitoring()
    }

    /// Запускаем мониторинг с проверкой каждые 5 секунд.
    func startMonitoring() {
        stopMonitoring()  // Останавливаем предыдущий таймер, если был
        // Создаём таймер старым способом
        let newTimer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkDirectoryChanges()
        }
        // Сохраняем ссылку в свойство
        timer = newTimer
        // Добавляем таймер в текущий run loop (обычно .commonModes)
        RunLoop.main.add(newTimer, forMode: .common)
    }

    /// Останавливаем мониторинг, если он идёт (инвалидируем таймер).
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Проверяем, не изменилась ли дата модификации директории.
    private func checkDirectoryChanges() {
        do {
            // Получаем атрибуты файла (синхронно)
            let attributes = try FileManager.default.attributesOfItem(atPath: directoryURL.path)
            // Выделяем дату модификации
            guard let modificationDate = attributes[.modificationDate] as? Date else { return }
            // Если новая дата отличается от старой, вызываем колбэк
            if let lastDate = lastModificationDate, lastDate != modificationDate {
                onDirectoryChanged?()
            }
            // Сохраняем дату, чтобы сравнить в следующий раз
            lastModificationDate = modificationDate
        } catch {
            print("Ошибка при проверке директории: \(error.localizedDescription)")
        }
    }
}

extension DirectoryMonitor: @unchecked Sendable {}
