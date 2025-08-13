//
//  SelectionHistory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 03.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import AppKit
import Combine
import Foundation

final class SelectionsHistory: ObservableObject {
    @Published private(set) var recentSelections: [String] = []
    private let userDefaultsKey = "SelectionsHistory"

    // MARK: - -
    init() {
        log.info(#function + " - Initializing SelectionsHistory")
        load()
    }

    // MARK: - -
    func add(_ path: String) {
        log.info(#function + " - \(path)")
        guard !path.isEmpty else {
            return
        }
        let pathAsNSString = (path as NSString).standardizingPath
        if recentSelections.first != pathAsNSString {
            recentSelections.insert(pathAsNSString, at: 0)
            recentSelections = Array(recentSelections.prefix(32))
            save()
        }
    }

    // MARK: - -
    private func save() {
        log.info(#function + " - \(recentSelections)")
        UserDefaults.standard.set(recentSelections, forKey: userDefaultsKey)
    }

    // MARK: - -
    private func load() {
        log.info(#function + " - Loading recent selections")
        recentSelections = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
}
