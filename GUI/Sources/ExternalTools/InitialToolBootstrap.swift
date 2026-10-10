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
            || !ExternalToolCatalog.lottieConvert.isInstalled
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
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MiMiNavigator/ToolBootstrap", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let statusURL = directory.appendingPathComponent("status-\(UUID().uuidString).txt")
            let scriptURL = directory.appendingPathComponent("install-\(UUID().uuidString).zsh")
            try script(statusURL: statusURL).write(to: scriptURL, atomically: true, encoding: .utf8)
            let command = "zsh \(Self.shellQuote(scriptURL.path))"
            let source = "tell application \"Terminal\" to do script \(command.appleScriptQuoted)"
            var error: NSDictionary?
            guard NSAppleScript(source: source)?.executeAndReturnError(&error) != nil else {
                throw BootstrapError.terminal(error?[NSAppleScript.errorMessage] as? String ?? "Terminal could not be opened")
            }
            pollTask = Task { [weak self] in
                await self?.poll(statusURL: statusURL, scriptURL: scriptURL)
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
                try? FileManager.default.removeItem(at: statusURL)
                try? FileManager.default.removeItem(at: scriptURL)
                ExternalToolRegistry.shared.refreshAll()
                if result == "done", !Self.needsSetup {
                    finish()
                } else {
                    isRunning = false
                    errorMessage = result == "done"
                        ? "Installation finished, but one or more tools are still unavailable. Check Terminal and retry."
                        : "Installation stopped. Check the Terminal output, then retry."
                    log.error("[ToolBootstrap] \(errorMessage ?? "installation failed")")
                }
                return
            }
            try? await Task.sleep(for: .seconds(1))
        }
        isRunning = false
        errorMessage = "Installation has not finished. Check Terminal and retry if needed."
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
        let installLottie = !ExternalToolCatalog.lottieConvert.isInstalled
        let formulaCommands = formulas.map { "\"$brew\" install \($0)" }.joined(separator: "\n")
        let lottieCommands = installLottie ? """
            "$brew" install pipx
            PIPX_BIN_DIR="$HOME/.local/bin" "$(dirname "$brew")/pipx" install --force lottie
            if [[ -x "$HOME/.local/bin/lottie_convert.py" && ! -e "$(dirname "$brew")/lottie_convert.py" ]]; then
                /bin/ln -s "$HOME/.local/bin/lottie_convert.py" "$(dirname "$brew")/lottie_convert.py"
            fi
            """ : ""
        return #"""
            #!/bin/zsh
            set -e
            status_file=\#(Self.shellQuote(statusURL.path))
            TRAPEXIT() {
                local result=$?
                if [[ -n "${package_dir:-}" ]]; then
                    /bin/rm -rf -- "$package_dir"
                fi
                if (( result == 0 )); then
                    print -r -- done > "$status_file"
                else
                    print -r -- failed > "$status_file"
                fi
            }
            brew=/opt/homebrew/bin/brew
            if [[ ! -x "$brew" && -x /usr/local/bin/brew ]]; then
                brew=/usr/local/bin/brew
            fi
            if [[ ! -x "$brew" ]]; then
                print 'Installing Homebrew from the official signed package…'
                package_dir=$(mktemp -d "${TMPDIR:-/tmp}/miminavigator-homebrew.XXXXXX")
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
            print 'Installing MiMiNavigator command-line tools…'
            \#(formulaCommands)
            \#(lottieCommands)
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
        case .terminal(let message): "Terminal automation could not start: \(message)"
        }
    }
}
