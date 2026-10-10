// GitClientRegistry.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Available Git clients, preferred client, and repository opening.

import AppKit
import SwiftUI

// MARK: - Git Client
enum GitClient: String, CaseIterable, Identifiable {
    case terminal, fork, githubDesktop, sourcetree, tower, sublimeMerge

    var id: String { rawValue }

    var name: String {
        switch self {
            case .terminal: return "Terminal"
            case .fork: return "Fork"
            case .githubDesktop: return "GitHub Desktop"
            case .sourcetree: return "Sourcetree"
            case .tower: return "Tower"
            case .sublimeMerge: return "Sublime Merge"
        }
    }

    var appName: String? {
        switch self {
            case .terminal: return nil
            case .fork: return "Fork.app"
            case .githubDesktop: return "GitHub Desktop.app"
            case .sourcetree: return "Sourcetree.app"
            case .tower: return "Tower.app"
            case .sublimeMerge: return "Sublime Merge.app"
        }
    }

    var cask: String? {
        switch self {
            case .terminal: return nil
            case .fork: return "fork"
            case .githubDesktop: return "github"
            case .sourcetree: return "sourcetree"
            case .tower: return "tower"
            case .sublimeMerge: return "sublime-merge"
        }
    }

    var website: URL? {
        let address: String
        switch self {
            case .terminal: return nil
            case .fork: address = "https://fork.dev/"
            case .githubDesktop: address = "https://desktop.github.com/"
            case .sourcetree: address = "https://www.sourcetreeapp.com/"
            case .tower: address = "https://www.git-tower.com/"
            case .sublimeMerge: address = "https://www.sublimemerge.com/"
        }
        return URL(string: address)
    }
}

// MARK: - Git Client Registry
@MainActor
@Observable
final class GitClientRegistry {
    static let shared = GitClientRegistry()
    private static let preferenceKey = "GitClientRegistry.preferredClient"
    private(set) var installedClients: Set<GitClient> = [.terminal]
    private(set) var preferredClient: GitClient

    private init() {
        preferredClient = GitClient(rawValue: UserDefaults.standard.string(forKey: Self.preferenceKey) ?? "") ?? .terminal
        refreshAvailability()
    }

    func setPreferred(_ client: GitClient) {
        preferredClient = client
        UserDefaults.standard.set(client.rawValue, forKey: Self.preferenceKey)
    }

    func refreshAvailability() {
        installedClients = Set(GitClient.allCases.filter { appURL(for: $0) != nil })
    }

    func isInstalled(_ client: GitClient) -> Bool {
        installedClients.contains(client)
    }

    func open(_ client: GitClient, repository: URL) {
        if client == .terminal {
            CntMenuCoord.shared.openTerminal(at: repository)
            return
        }
        guard let application = appURL(for: client) else { return }
        NSWorkspace.shared.open([repository], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { log.error("[GitClient] failed to open \(client.name): \(error.localizedDescription)") }
        }
    }

    func openPreferred(repository: URL) {
        refreshAvailability()
        open(isInstalled(preferredClient) ? preferredClient : .terminal, repository: repository)
    }

    func install(_ client: GitClient) {
        guard let cask = client.cask else { return }
        guard let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            if let website = client.website { NSWorkspace.shared.open(website) }
            return
        }
        let command = "\(brew) install --cask \(cask)"
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"\(escaped)\""
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error { log.error("[GitClient] install failed to start: \(error)") }
    }

    private func appURL(for client: GitClient) -> URL? {
        guard let name = client.appName else { return URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app") }
        for directory in ["/Applications", "\(NSHomeDirectory())/Applications"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
