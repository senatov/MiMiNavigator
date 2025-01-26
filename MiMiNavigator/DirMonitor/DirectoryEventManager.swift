//
//  Untitled.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.01.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

//
//  DirectoryEventManager.swift
//  Слой, который "перехватывает" сырые события мониторинга,
//  и дополняет их бизнес-логикой, фильтрацией, буферизацией и т.п.
//

import Foundation

final class DirectoryEventManager {
    // Тут можно хранить какие-то дополнительные состояния,
    // например, время последнего изменения, счётчик изменений и т.д.
    private var lastKnownState: String = "OK"

    // Колбэк для клиента, говорим: "У нас есть новое событие"
    var onStateUpdated: ((String) -> Void)?

    init() {}

    // Допустим, этот метод вызывается, когда `DirectoryMonitor` говорит "изменение"
    func handleDirectoryChangeEvent() {
        // Здесь может быть сложная логика:
        // - проверка реального контента директории
        // - фильтрация файлов
        // - задержки и пр.

        // Для примера просто меняем некую строку
        lastKnownState = "Directory has changed!"
        onStateUpdated?(lastKnownState)
    }
}
