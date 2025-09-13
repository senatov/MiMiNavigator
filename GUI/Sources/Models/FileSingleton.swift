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
    private var _leftFiles: [CustomFile] = []  // Private storage for L-files
    private var _rightFiles: [CustomFile] = []  // Private storage for R-files


    // MARK: - Function to notify SwiftUI observers of changes
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

    // MARK: -
    func getLeftFiles() async -> [CustomFile] {
        _leftFiles
    }

    // MARK: -
    func getRightFiles() async -> [CustomFile] {
        _rightFiles
    }
}
