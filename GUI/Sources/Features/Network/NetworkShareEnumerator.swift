// NetworkShareEnumerator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enumerates SMB/AFP shares via smbutil and Keychain credentials.
//   Tries guest access first, then known credentials, across resolved hostname variants.

import Foundation
import Security

// MARK: - Keychain credential entry
struct KeychainCred: Hashable, Sendable {
    let user: String
    let password: String
    let server: String
}

// MARK: - Share enumeration (smbutil + Keychain)
enum NetworkShareEnumerator {

    private static let smbUtilPath = "/usr/bin/smbutil"
    private static let smbUtilTimeoutSeconds: Double = 7
    private static let smbUtilErrorPreviewLength = 400

    private static func normalizedBaseName(for host: NetworkHost) -> String {
        host.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".fritz.box", with: "")
    }

    private static func sanitizedHostName(_ hostName: String) -> String? {
        guard !hostName.isEmpty, hostName != "(nil)" else { return nil }
        return hostName
    }

    private static func isUsableCandidateHost(_ value: String) -> Bool {
        !value.isEmpty && value != "(nil)"
    }

    private static func trimmedTrailingDot(_ value: String) -> String {
        value.hasSuffix(".") ? String(value.dropLast()) : value
    }

    private static func normalizedLookupHost(_ value: String) -> String {
        normalizedAddressLikeValue(value)
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".fritz.box", with: "")
    }

    private static func normalizedAddressLikeValue(_ value: String) -> String {
        trimmedTrailingDot(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func deduplicatedPreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let normalizedValue = normalizedAddressLikeValue(value)
            guard !normalizedValue.isEmpty else { continue }

            let lowercasedValue = normalizedValue.lowercased()
            guard seen.insert(lowercasedValue).inserted else { continue }

            result.append(normalizedValue)
        }

        return result
    }

    private static func credentialSummary(_ credentials: [KeychainCred]) -> [String] {
        credentials.map { "\($0.user)@\($0.server)" }
    }

    private static func logShareAttempt(hostname: String, user: String?) {
        let authLabel = diagnosticCredentialLabel(user: user, server: hostname)
        log.debug("[ShareEnum] trying \(authLabel)")
    }

    private static func hasSuccessfulShares(_ shares: [NetworkShare]) -> Bool {
        !shares.isEmpty
    }

    private static func diagnosticCredentialLabel(user: String?, server: String? = nil) -> String {
        if let user, !user.isEmpty {
            if let server, !server.isEmpty {
                return "\(user)@\(server)"
            }
            return user
        }
        return "guest"
    }

    private static func maskedSmbUtilTarget(hostname: String, user: String?) -> String {
        guard let user, !user.isEmpty else {
            return "//\(hostname)"
        }
        return "//\(user):***@\(hostname)"
    }

    private static func shouldLogSmbUtilStderr(exitStatus: Int32, stderr: String) -> Bool {
        exitStatus != 0 || !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func readPipeText(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func logSmbUtilResult(
        hostname: String,
        maskedTarget: String,
        credentialLabel: String,
        exitStatus: Int32,
        stdout: String,
        stderr: String
    ) {
        log.debug("[smbutil] host=\(hostname) target=\(maskedTarget)")
        log.debug("[smbutil] auth=\(credentialLabel) exit=\(exitStatus)")

        let stdoutPreview = stdout.prefix(smbUtilErrorPreviewLength)
        if !stdoutPreview.isEmpty {
            log.debug("[smbutil] stdout=\(stdoutPreview)")
        }

        guard shouldLogSmbUtilStderr(exitStatus: exitStatus, stderr: stderr) else { return }

        let stderrPreview = stderr.prefix(smbUtilErrorPreviewLength)
        if !stderrPreview.isEmpty {
            if exitStatus == 0 {
                log.debug("[smbutil] stderr=\(stderrPreview)")
            } else {
                log.warning("[smbutil] stderr=\(stderrPreview)")
            }
        }
    }

    // MARK: - Main entry point
    @concurrent static func shares(for host: NetworkHost) async -> [NetworkShare] {
        let scheme = host.serviceType.urlScheme
        let hostnameCandidates = hostnameVariants(host)
        let credentials = keychainCredentials(for: host)

        guard shouldUseSmbUtil(for: host) else {
            log.info("[ShareEnum] unsupported service for smbutil: \(host.serviceType.rawValue) host='\(host.name)'")
            return []
        }

        log.info("[ShareEnum] host='\(host.name)' localhost=\(host.isLocalhost)")
        log.debug("[ShareEnum] candidates=\(hostnameCandidates)")
        log.debug("[ShareEnum] creds=\(credentialSummary(credentials))")

        guard !hostnameCandidates.isEmpty else {
            log.warning("[ShareEnum] no hostname candidates for '\(host.name)'")
            return []
        }

        // For localhost or any host: try guest/anonymous FIRST
        // macOS shares public folders (e.g. Public Folder) without auth
        for hostname in hostnameCandidates {
            logShareAttempt(hostname: hostname, user: nil)
            let result = await smbUtilShares(
                hostname: hostname,
                user: nil,
                password: nil,
                scheme: scheme
            )
            if hasSuccessfulShares(result) {
                log.info("[ShareEnum] OK guest@\(hostname) -> \(result.map(\.name))")
                return result
            }
        }

        // Skip credentials for localhost (should never need them)
        guard !host.isLocalhost else {
            log.info("[ShareEnum] localhost no guest shares found")
            return []
        }

        // Try each credential x each hostname
        for cred in credentials {
            for hostname in hostnameCandidates {
                logShareAttempt(hostname: hostname, user: cred.user)
                let result = await smbUtilShares(
                    hostname: hostname,
                    user: cred.user,
                    password: cred.password,
                    scheme: scheme
                )
                if hasSuccessfulShares(result) {
                    log.info("[ShareEnum] OK \(cred.user)@\(hostname) -> \(result.map(\.name))")
                    return result
                }
            }
        }

        log.info("[ShareEnum] no shares for '\(host.name)' - auth required")
        return []
    }

    // MARK: - Hostname variants to try (priority order)
    static func hostnameVariants(_ host: NetworkHost) -> [String] {
        var candidates: [String] = []

        let resolvedHostName = sanitizedHostName(host.hostName).map(normalizedAddressLikeValue)
        let effectiveHostName = normalizedAddressLikeValue(host.effectiveHostName)
        let displayHostName = normalizedAddressLikeValue(host.hostDisplayName)
        let baseName = normalizedLookupHost(host.name)

        if let resolvedHostName, resolvedHostName != normalizedAddressLikeValue(host.name) {
            candidates.append(resolvedHostName)
        }

        if isUsableCandidateHost(effectiveHostName) {
            candidates.append(effectiveHostName)
        }

        if isUsableCandidateHost(displayHostName) {
            candidates.append(displayHostName)
        }

        if isUsableCandidateHost(baseName) {
            candidates.append("\(baseName).fritz.box")
            candidates.append("\(baseName).local")
            candidates.append(baseName)
        }

        return deduplicatedPreservingOrder(candidates.filter(isUsableCandidateHost))
    }

    private static func keychainServerVariants(for host: NetworkHost) -> [String] {
        let resolvedHostName = sanitizedHostName(host.hostName).map(normalizedAddressLikeValue)
        let effectiveHostName = normalizedAddressLikeValue(host.effectiveHostName)
        let displayHostName = normalizedAddressLikeValue(host.hostDisplayName)
        let baseName = normalizedLookupHost(host.name)

        let rawVariants: [String?] = [
            resolvedHostName,
            isUsableCandidateHost(effectiveHostName) ? effectiveHostName : nil,
            isUsableCandidateHost(displayHostName) ? displayHostName : nil,
            isUsableCandidateHost(baseName) ? baseName : nil,
            isUsableCandidateHost(baseName) ? "\(baseName).local" : nil,
            isUsableCandidateHost(baseName) ? "\(baseName).local." : nil,
            isUsableCandidateHost(baseName) ? "\(baseName).fritz.box" : nil,
            isUsableCandidateHost(baseName) ? "\(baseName)._smb._tcp.local" : nil,
            isUsableCandidateHost(baseName) ? "\(baseName)._afp._tcp.local" : nil,
        ]

        return deduplicatedPreservingOrder(rawVariants.compactMap { $0 })
    }

    // MARK: - Load all Keychain internet passwords for this host
    static func keychainCredentials(for host: NetworkHost) -> [KeychainCred] {
        let serverVariants = keychainServerVariants(for: host)

        var results: [KeychainCred] = []
        var seen = Set<String>()

        for server in serverVariants {
            let query: [CFString: Any] = [
                kSecClass: kSecClassInternetPassword,
                kSecAttrServer: server,
                kSecMatchLimit: kSecMatchLimitAll,
                kSecReturnAttributes: true,
                kSecReturnData: true,
            ]
            var items: AnyObject? = nil
            let status = SecItemCopyMatching(query as CFDictionary, &items)
            guard status == errSecSuccess,
                  let array = items as? [[CFString: Any]]
            else {
                continue
            }

            for item in array {
                let account = item[kSecAttrAccount] as? String ?? ""
                let data = item[kSecValueData] as? Data ?? Data()
                let password = String(data: data, encoding: .utf8) ?? ""

                guard !account.isEmpty,
                      account != "No user account",
                      !password.isEmpty
                else {
                    continue
                }

                let key = "\(account.lowercased()):\(password):\(server.lowercased())"
                guard seen.insert(key).inserted else { continue }

                results.append(KeychainCred(user: account, password: password, server: server))
                log.debug("[Keychain] found \(account)@\(server)")
            }
        }

        return results
    }

    private static func smbUtilTarget(hostname: String, user: String?, password: String?) -> String {
        guard let user, let password else {
            return "//\(hostname)"
        }

        let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
        return "//\(user):\(encodedPassword)@\(hostname)"
    }

    private static func scheduleSmbUtilTimeout(for process: Process) {
        DispatchQueue.global().asyncAfter(deadline: .now() + smbUtilTimeoutSeconds) {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    private static func shouldUseSmbUtil(for host: NetworkHost) -> Bool {
        host.serviceType == .smb
    }

    // MARK: - Run smbutil view
    @concurrent private static func smbUtilShares(
        hostname: String, user: String?, password: String?, scheme: String
    ) async -> [NetworkShare] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let target = smbUtilTarget(hostname: hostname, user: user, password: password)
                let maskedTarget = maskedSmbUtilTarget(hostname: hostname, user: user)
                let credentialLabel = diagnosticCredentialLabel(user: user, server: hostname)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: smbUtilPath)
                process.arguments = ["view", target]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    log.warning("[smbutil] launch failed host=\(hostname)")
                    log.warning("[smbutil] auth=\(credentialLabel)")
                    log.warning("[smbutil] error=\(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                scheduleSmbUtilTimeout(for: process)
                process.waitUntilExit()

                let stdout = readPipeText(outPipe)
                let stderr = readPipeText(errPipe)

                logSmbUtilResult(
                    hostname: hostname,
                    maskedTarget: maskedTarget,
                    credentialLabel: credentialLabel,
                    exitStatus: process.terminationStatus,
                    stdout: stdout,
                    stderr: stderr
                )

                continuation.resume(returning: parseSmbUtil(output: stdout, hostname: hostname, scheme: scheme))
            }
        }
    }

    private static func makeShareURL(scheme: String, hostname: String, shareName: String) -> URL? {
        let encodedShareName = shareName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? shareName
        return URL(string: "\(scheme)://\(hostname)/\(encodedShareName)")
    }

    private static func isVisibleShareName(_ shareName: String) -> Bool {
        !shareName.hasSuffix("$") && shareName != "IPC$"
    }

    private static func deduplicatedSharesPreservingOrder(_ shares: [NetworkShare]) -> [NetworkShare] {
        var seen = Set<String>()
        var result: [NetworkShare] = []

        for share in shares {
            let key = share.url.absoluteString.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(share)
        }

        return result
    }

    // MARK: - Parse smbutil output, skip hidden shares ($)
    private static func parseSmbUtil(output: String, hostname: String, scheme: String) -> [NetworkShare] {
        var shares: [NetworkShare] = []
        var inTable = false

        for line in output.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("------") {
                inTable = true
                continue
            }

            guard inTable, !trimmedLine.isEmpty else { continue }

            let parts = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let diskIndex = parts.firstIndex(where: { $0.lowercased() == "disk" }), diskIndex > 0 else {
                continue
            }

            let shareName = parts[0..<diskIndex].joined(separator: " ")
            guard isVisibleShareName(shareName) else { continue }

            guard let url = makeShareURL(scheme: scheme, hostname: hostname, shareName: shareName) else {
                continue
            }

            shares.append(NetworkShare(name: shareName, url: url))
        }

        return deduplicatedSharesPreservingOrder(shares)
    }

    // MARK: - Best single hostname for external use
    static func resolvedHostname(_ host: NetworkHost) -> String {
        hostnameVariants(host).first ?? host.name
    }
}
