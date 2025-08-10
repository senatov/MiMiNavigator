//
//  SelectionHistory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.07.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import AppKit
import Combine
import Foundation

final class SelectionsHistory: ObservableObject {
    @Published private(set) var recentSelections: [String] = []
    private let userDefaultsKey = "SelectionsHistory"

    init() {
        load()
    }

    func add(_ path: String) {
        guard !path.isEmpty else { return }
        let pathAsNSString = (path as NSString).standardizingPath
        if recentSelections.first != pathAsNSString {
            recentSelections.insert(pathAsNSString, at: 0)
            recentSelections = Array(recentSelections.prefix(32))
            save()
        }
    }

    private func save() {
        UserDefaults.standard.set(recentSelections, forKey: userDefaultsKey)
    }

    private func load() {
        recentSelections = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
}
