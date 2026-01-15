// FileSingleton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - Thread-safe file storage actor
actor FileSingleton {
    static let shared = FileSingleton()
    
    private var _leftFiles: [CustomFile] = []
    private var _rightFiles: [CustomFile] = []

    // MARK: - Update left panel files
    func updateLeftFiles(_ files: [CustomFile]) {
        _leftFiles = files
    }

    // MARK: - Update right panel files
    func updateRightFiles(_ files: [CustomFile]) {
        _rightFiles = files
    }

    // MARK: - Get left panel files
    func getLeftFiles() -> [CustomFile] {
        _leftFiles
    }

    // MARK: - Get right panel files
    func getRightFiles() -> [CustomFile] {
        _rightFiles
    }
}
