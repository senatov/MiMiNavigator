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

    private init() {
        LogMan.log.debug("init() - empty")
    }

    // MARK: -
    func updateLeftFiles(_ files: [CustomFile]) async {
        _leftFiles = files
        await notifyObservers()
    }

    // MARK: -
    func updateRightFiles(_ files: [CustomFile]) async {
        _rightFiles = files
        await notifyObservers()
    }

    // MARK: - Non-isolated accessor methods to allow safe access for SwiftUI
    nonisolated func getLeftFiles() async -> [CustomFile] {
        await _leftFiles
    }

    // MARK: -
    nonisolated func getRightFiles() async -> [CustomFile] {
        await _rightFiles
    }

    // Function to notify SwiftUI observers of changes
    @MainActor
    private func notifyObservers() {
        objectWillChange.send()
    }
}
