    //
    //  AppState.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 06.04.25.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import Foundation
import SwiftUI

    /// Singleton хранилище состояния приложения
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Panel {
        case left
        case right
    }

        /// Активная панель (для определения фокуса)
    @Published var activePanel: Panel = .left

        /// Текущий путь в левой панели
    @Published var leftPanelPath: String = FileManager.default.homeDirectoryForCurrentUser.path

        /// Текущий путь в правой панели
    @Published var rightPanelPath: String = FileManager.default.homeDirectoryForCurrentUser.path

        /// Последний выбранный файл в левой панели
    @Published var selectedLeftFile: CustomFile? = nil

        /// Последний выбранный файл в правой панели
    @Published var selectedRightFile: CustomFile? = nil

        /// Возвращает текущий путь активной панели
    var currentDirectory: String {
        switch activePanel {
            case .left:
                return leftPanelPath
            case .right:
                return rightPanelPath
        }
    }

        /// Возвращает последний выбранный файл в активной панели
    var selectedFile: CustomFile? {
        switch activePanel {
            case .left:
                return selectedLeftFile
            case .right:
                return selectedRightFile
        }
    }

    private init() { }
}
