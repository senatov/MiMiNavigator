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

        private var recentSelections: [URL] = []
        private static let maxEntries = 128

        // MARK: - Core visit logic
        private func visit(_ url: URL, recordHistory: Bool) {

            let normalized = url.standardizedFileURL

            // Ignore navigation to the same location
            if current?.standardizedFileURL == normalized {
                return
            }

            if recordHistory {

                // Only track directories in navigation history
                guard normalized.hasDirectoryPath else { return }

                if let current, backStack.last != current {
                    backStack.append(current)
                }

                forwardStack.removeAll()
                trimHistory()

            } else {

                // Track recent selections (most recent first, no duplicates)
                if let idx = recentSelections.firstIndex(where: { $0.standardizedFileURL == normalized }) {
                    recentSelections.remove(at: idx)
                }

                recentSelections.insert(normalized, at: 0)

                if recentSelections.count > Self.maxEntries {
                    recentSelections.removeLast()
                }
            }

            current = normalized
            updateNavigationState()
        }

        func navigate(to url: URL) {
            visit(url, recordHistory: true)
        }

        func setCurrent(to url: URL) {
            visit(url, recordHistory: false)
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

        // MARK: - Recent selections for UI

        func getRecentSelections(limit: Int = 10) -> [URL] {
            Array(recentSelections.prefix(limit))
        }

        // MARK: - Remove entry from recent selections

        func remove(_ url: URL) {
            let normalized = url.standardizedFileURL
            recentSelections.removeAll { $0.standardizedFileURL == normalized }
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
            recentSelections.removeAll()
            current = nil
            updateNavigationState()
        }
    }
