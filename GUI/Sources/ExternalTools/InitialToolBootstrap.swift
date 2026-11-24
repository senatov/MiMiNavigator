// InitialToolBootstrap.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Installs required first-run command-line tools in Terminal.

import AppKit
import ExternalToolsKit
import Foundation

// MARK: - Initial Tool Bootstrap
@MainActor
@Observable
final class InitialToolBootstrap {
    private static let formulaTools: [ExternalTool] = [
        ExternalToolCatalog.sevenZip,
        ExternalToolCatalog.unar,
        ExternalToolCatalog.sshpass,
        ExternalToolCatalog.ffmpeg,
        ExternalToolCatalog.ffprobe,
        ExternalToolCatalog.gifski,
    ]
    private static let gitPaths = ["/opt/homebrew/bin/git", "/usr/local/bin/git"]
    private(set) var isRunning = false
    private(set) var isComplete = false
    private(set) var errorMessage: String?
    private(set) var statusMessage = "Preparing required tools…"
    private var pollTask: Task<Void, Never>?

    static var needsSetup: Bool {
        let fileManager = FileManager.default
        return !ExternalToolCatalog.brew.isInstalled
            || !gitPaths.contains(where: fileManager.isExecutableFile(atPath:))
            || formulaTools.contains(where: { !$0.isInstalled })
    }

    // MARK: - Start Installation
    func start() {
        guard !isRunning, !isComplete else { return }
        if !Self.needsSetup {
            finish()
            return
        }
        isRunning = true
        errorMessage = nil
        statusMessage = ExternalToolCatalog.brew.isInstalled
            ? "Installing missing command-line tools in Terminal…"
            : "Installing Homebrew in Terminal…"
        do {
            let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)
                .appendingPathComponent("miminavigator-tool-bootstrap-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let statusURL = directory.appendingPathComponent("status-\(UUID().uuidString).txt")
            let scriptURL = directory.appendingPathComponent("install-\(UUID().uuidString).command")
            try script(statusURL: statusURL).write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                throw BootstrapError.terminal("Terminal could not be found")
            }
            log.info("[ToolBootstrap] opening installer in Terminal")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            pollTask = Task { [weak self] in
                await self?.poll(statusURL: statusURL, scriptURL: scriptURL)
            }
            NSWorkspace.shared.open([scriptURL], withApplicationAt: terminalURL, configuration: configuration) { [weak self] _, error in
                guard let error else { return }
                Task { @MainActor [weak self] in
                    self?.pollTask?.cancel()
                    self?.pollTask = nil
                    self?.isRunning = false
                    self?.errorMessage = "Terminal could not be opened: \(error.localizedDescription)"
                    log.error("[ToolBootstrap] \(error.localizedDescription)")
                }
            }
        } catch {
            isRunning = false
            errorMessage = error.localizedDescription
            log.error("[ToolBootstrap] \(error.localizedDescription)")
        }
    }

    // MARK: - Poll Installer Result
    private func poll(statusURL: URL, scriptURL: URL) async {
        for _ in 0..<3600 {
            if Task.isCancelled { return }
            if ExternalToolCatalog.brew.isInstalled, statusMessage == "Installing Homebrew in Terminal…" {
                statusMessage = "Installing missing command-line tools in Terminal…"
            }
            if let result = try? String(contentsOf: statusURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
                log.info("[ToolBootstrap] installer result=\(result)")
                try? FileManager.default.removeItem(at: statusURL)
                try? FileManager.default.removeItem(at: scriptURL)
                try? FileManager.default.removeItem(at: scriptURL.deletingLastPathComponent())
                pollTask = nil
                ExternalToolRegistry.shared.refreshAll()
                if result == "done", !Self.needsSetup {
                    finish()
                } else {
                    isRunning = false
                    switch result {
                    case "done":
                        errorMessage = "Installation finished, but one or more tools are still unavailable. Check Terminal and retry."
                    case "needs-admin":
                        errorMessage = "An administrator must install Homebrew first. You can continue without the missing tools."
                    case "needs-owner":
                        errorMessage = "Homebrew belongs to another account. Ask its owner or an administrator to install the missing tools."
                    default:
                        errorMessage = "Installation stopped. Check the Terminal output, then retry."
                    }
                    log.error("[ToolBootstrap] \(errorMessage ?? "installation failed")")
                }
                return
            }
            try? await Task.sleep(for: .seconds(1))
        }
        isRunning = false
        errorMessage = "Installation has not finished. Check Terminal and retry if needed."
        log.error("[ToolBootstrap] installer timed out")
    }

    // MARK: - Complete Setup
    private func finish() {
        isRunning = false
        isComplete = true
        statusMessage = "Required tools are ready."
        ExternalToolRegistry.shared.refreshAll()
    }

    // MARK: - Installer Script
    private func script(statusURL: URL) -> String {
        let missingFormulas = Self.formulaTools
            .filter { !$0.isInstalled }
            .compactMap(\.brewFormula)
        let formulas = ([Self.gitPaths.contains(where: FileManager.default.isExecutableFile(atPath:)) ? nil : "git"] + missingFormulas)
            .compactMap { $0 }
            .reduce(into: [String]()) { result, formula in
                if !result.contains(formula) { result.append(formula) }
            }
        let formulaCommands = formulas.map { "\"${brew_command[@]}\" install \($0)" }.joined(separator: "\n")
        return #"""
            #!/bin/zsh
            set -e
            status_file=\#(Self.shellQuote(statusURL.path))
            failure_reason=failed
            TRAPEXIT() {
                local result=$?
                if [[ -n "${package_dir:-}" ]]; then
                    /bin/rm -rf -- "$package_dir"
                fi
                if (( result == 0 )); then
                    print -r -- done > "$status_file"
                else
                    print -r -- "$failure_reason" > "$status_file"
                fi
            }
            is_admin() { [[ " $(/usr/bin/id -Gn) " == *" admin "* ]] }
            brew=/opt/homebrew/bin/brew
            if [[ ! -x "$brew" && -x /usr/local/bin/brew ]]; then
                brew=/usr/local/bin/brew
            fi
            if [[ ! -x "$brew" ]]; then
                if ! is_admin; then
                    print -u2 'An administrator must provision Homebrew for this account before tools can be installed.'
                    failure_reason=needs-admin
                    exit 1
                fi
                print 'Installing Homebrew from the official signed package…'
                package_dir=$(mktemp -d /tmp/miminavigator-homebrew.XXXXXX)
                /usr/bin/curl --fail --location --show-error --retry 3 \
                    --output "$package_dir/Homebrew.pkg" \
                    https://github.com/Homebrew/brew/releases/latest/download/Homebrew.pkg
                /usr/sbin/spctl --assess --type install --verbose "$package_dir/Homebrew.pkg"
                /usr/bin/sudo /usr/sbin/installer -pkg "$package_dir/Homebrew.pkg" -target /
            fi
            if [[ ! -x "$brew" ]]; then
                print -u2 'Homebrew installation did not produce a usable brew executable.'
                exit 1
            fi
            brew_prefix=${brew%/bin/brew}
            brew_owner=$(/usr/bin/stat -f %Su "$brew_prefix")
            brew_command=(/usr/bin/env)
            if [[ "$brew_owner" == root ]]; then
                print -u2 'The Homebrew prefix is owned by root and must be repaired by an administrator.'
                failure_reason=needs-owner
                exit 1
            fi
            if [[ "$brew_owner" != "$(/usr/bin/id -un)" ]]; then
                if ! is_admin; then
                    print -u2 "Homebrew belongs to $brew_owner. Ask its owner or an administrator to install the missing tools."
                    failure_reason=needs-owner
                    exit 1
                fi
                brew_command=(/usr/bin/sudo -H -u "$brew_owner" /usr/bin/env)
                log_dir=$(/usr/bin/sudo -H -u "$brew_owner" /usr/bin/mktemp -d /tmp/miminavigator-homebrew-logs.XXXXXX)
            else
                log_dir=$(/usr/bin/mktemp -d /tmp/miminavigator-homebrew-logs.XXXXXX)
            fi
            brew_command+=("HOMEBREW_LOGS=$log_dir" "$brew")
            print 'Installing MiMiNavigator command-line tools…'
            \#(formulaCommands)
            print 'MiMiNavigator command-line tools are ready.'
            """#
    }

    // MARK: - Shell Quoting
    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

// MARK: - Bootstrap Error
private enum BootstrapError: LocalizedError {
    case terminal(String)

    var errorDescription: String? {
        switch self {
        case .terminal(let message): "Terminal installer could not start: \(message)"
        }
    }
}
