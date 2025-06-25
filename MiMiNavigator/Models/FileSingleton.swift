//
//  FileSinglton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import Combine
import Foundation

actor FileSingleton: ObservableObject, @unchecked Sendable {
    static let shared = FileSingleton()
    private var _leftFiles: [CustomFile] = []  // Private storage for left files
    private var _rightFiles: [CustomFile] = []  // Private storage for right files


    // Function to notify SwiftUI observers of changes
    @MainActor
    private func notifyObservers() {
        log.info(#function)
        objectWillChange.send()
    }

    // MARK: -
    func updateLeftFiles(_ files: [CustomFile]) async {
        log.info(#function)
        _leftFiles = files
        await notifyObservers()
    }

    // MARK: -
    func updateRightFiles(_ files: [CustomFile]) async {
        log.info(#function)
        _rightFiles = files
        await notifyObservers()
    }

    // MARK: - Non-isolated accessor methods to allow safe access for SwiftUI
    @concurrent
    nonisolated func getLeftFiles() async -> [CustomFile] {
        await _leftFiles
    }

    // MARK: -
    @concurrent
    nonisolated func getRightFiles() async -> [CustomFile] {
        await _rightFiles
    }
}
