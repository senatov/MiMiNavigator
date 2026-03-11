    // SelectionsHistory.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 03.08.2024.
    //  Copyright © 2024 Senatov. All rights reserved.

    import Foundation

    // MARK: - Navigation history manager
    @MainActor
    @Observable
    final class SelectionsHistory {

        @ObservationIgnored
        private var backStack: [URL] = []

        @ObservationIgnored
        private var forwardStack: [URL] = []

        private(set) var current: URL?

        private(set) var canGoBack: Bool = false
        private(set) var canGoForward: Bool = false

        @ObservationIgnored
        private static let maxEntries = 100

        // MARK: - Navigation state

        // MARK: - Navigate to new location

        func navigate(to url: URL) {

            let normalized = url.standardizedFileURL

            // Ignore navigation to the same location
            if current == normalized {
                return
            }

            // Only track directories
            guard normalized.hasDirectoryPath else {
                return
            }

            // Avoid duplicate consecutive entries
            if let current, backStack.last != current {
                backStack.append(current)
            }

            current = normalized
            forwardStack.removeAll()

            trimHistory()
            updateNavigationState()
        }

        // MARK: - Back

        func goBack() -> URL? {

            guard let prev = backStack.popLast() else {
                return nil
            }

            if let current {
                forwardStack.append(current)
            }

            current = prev
            updateNavigationState()
            return prev
        }

        // MARK: - Forward

        func goForward() -> URL? {

            guard let next = forwardStack.popLast() else {
                return nil
            }

            if let current {
                backStack.append(current)
            }

            current = next
            updateNavigationState()
            return next
        }

        // MARK: - History lists for UI

        func getBackHistory(limit: Int = 10) -> [URL] {
            Array(backStack.suffix(limit).reversed())
        }

        func getForwardHistory(limit: Int = 10) -> [URL] {
            Array(forwardStack.suffix(limit))
        }

        // MARK: - History trimming

        private func trimHistory() {
            if backStack.count > Self.maxEntries {
                backStack.removeFirst(backStack.count - Self.maxEntries)
            }
        }

        private func updateNavigationState() {
            canGoBack = !backStack.isEmpty
            canGoForward = !forwardStack.isEmpty
        }

        // MARK: - Reset

        func clear() {
            backStack.removeAll()
            forwardStack.removeAll()
            current = nil
            updateNavigationState()
        }
    }
