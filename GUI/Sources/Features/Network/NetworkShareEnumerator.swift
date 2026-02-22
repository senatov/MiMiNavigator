// NetworkShareEnumerator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enumerates SMB/AFP shares via smbutil + Keychain credentials.
//              Tries all Keychain entries for the host, falls back to guest/anonymous.
//              Hostname fallback chain: hostName → name.fritz.box → name.local → bare

import Foundation
import Security

// MARK: - Keychain credential entry
struct KeychainCred {
    let user: String
    let password: String
    let server: String
}

// MARK: - Share enumeration (smbutil + Keychain)
enum NetworkShareEnumerator {

    // MARK: - Main entry point
    static func shares(for host: NetworkHost) async -> [NetworkShare] {
        let scheme = host.serviceType == .afp ? "afp" : "smb"
        let hostnameCandidates = hostnameVariants(host)
        let credentials = keychainCredentials(for: host)

        log.info("[ShareEnum] host='\(host.name)' localhost=\(host.isLocalhost) candidates=\(hostnameCandidates) creds=\(credentials.map { "\($0.user)@\($0.server)" })")

        // For localhost or any host: try guest/anonymous FIRST
        // macOS shares public folders (e.g. Public Folder) without auth
        for hostname in hostnameCandidates {
            let result = await smbUtilShares(hostname: hostname, user: nil,
                                             password: nil, scheme: scheme)
            if !result.isEmpty {
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
                let result = await smbUtilShares(hostname: hostname, user: cred.user,
                                                 password: cred.password, scheme: scheme)
                if !result.isEmpty {
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

        // 1. Bonjour-resolved hostName (most accurate)
        let hn = host.hostName
        if !hn.isEmpty && hn != "(nil)" && hn != host.name {
            candidates.append(hn)
            if hn.hasSuffix(".") { candidates.append(String(hn.dropLast())) }
        }

        // Strip known suffixes to get bare name
        let base = host.name
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".fritz.box", with: "")

        // 2. FritzBox DNS (most reliable on home networks with FritzBox)
        candidates.append("\(base).fritz.box")
        // 3. mDNS .local
        candidates.append("\(base).local")
        // 4. Bare name (NetBIOS)
        candidates.append(base)

        // Deduplicate, preserve order
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    // MARK: - Load all Keychain internet passwords for this host
    static func keychainCredentials(for host: NetworkHost) -> [KeychainCred] {
        let base = host.name
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
            .replacingOccurrences(of: ".fritz.box", with: "")

        var serverVariants: [String] = [
            base,
            "\(base).local",
            "\(base).local.",
            "\(base).fritz.box",
            "\(base)._smb._tcp.local",
            host.hostName,
        ]
        serverVariants = Array(Set(serverVariants.filter { !$0.isEmpty && $0 != "(nil)" }))

        var results: [KeychainCred] = []
        var seen = Set<String>()

        for server in serverVariants {
            let query: [CFString: Any] = [
                kSecClass:            kSecClassInternetPassword,
                kSecAttrServer:       server,
                kSecMatchLimit:       kSecMatchLimitAll,
                kSecReturnAttributes: true,
                kSecReturnData:       true,
            ]
            var items: AnyObject? = nil
            let status = SecItemCopyMatching(query as CFDictionary, &items)
            guard status == errSecSuccess,
                  let array = items as? [[CFString: Any]]
            else { continue }

            for item in array {
                let acct = item[kSecAttrAccount] as? String ?? ""
                let data = item[kSecValueData] as? Data ?? Data()
                let pass = String(data: data, encoding: .utf8) ?? ""
                guard !acct.isEmpty && acct != "No user account" && !pass.isEmpty else { continue }
                let key = "\(acct):\(pass)"
                guard seen.insert(key).inserted else { continue }
                results.append(KeychainCred(user: acct, password: pass, server: server))
                log.debug("[Keychain] found \(acct)@\(server)")
            }
        }
        return results
    }

    // MARK: - Run smbutil view
    private static func smbUtilShares(
        hostname: String, user: String?, password: String?, scheme: String
    ) async -> [NetworkShare] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let target: String
                if let u = user, let p = password {
                    let encPass = p.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? p
                    target = "//\(u):\(encPass)@\(hostname)"
                } else {
                    target = "//\(hostname)"
                }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/smbutil")
                process.arguments = ["view", target]
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError  = errPipe
                do { try process.run() } catch {
                    log.warning("[smbutil] launch failed \(hostname): \(error)")
                    continuation.resume(returning: [])
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 7) {
                    if process.isRunning { process.terminate() }
                }
                process.waitUntilExit()
                let data   = outPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                log.debug("[smbutil] \(hostname) exit=\(process.terminationStatus) out=\(output.prefix(400))")
                continuation.resume(returning: parseSmbUtil(output: output, hostname: hostname, scheme: scheme))
            }
        }
    }

    // MARK: - Parse smbutil output, skip hidden shares ($)
    private static func parseSmbUtil(output: String, hostname: String, scheme: String) -> [NetworkShare] {
        var shares: [NetworkShare] = []
        var inTable = false
        for line in output.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("------") { inTable = true; continue }
            guard inTable, !t.isEmpty else { continue }
            let parts = t.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let diskIdx = parts.firstIndex(where: { $0.lowercased() == "disk" }),
                  diskIdx > 0 else { continue }
            let name = parts[0..<diskIdx].joined(separator: " ")
            guard !name.hasSuffix("$") && name != "IPC$" else { continue }
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            if let url = URL(string: "\(scheme)://\(hostname)/\(encoded)") {
                shares.append(NetworkShare(name: name, url: url))
            }
        }
        return shares
    }

    // MARK: - Best single hostname for external use
    static func resolvedHostname(_ host: NetworkHost) -> String {
        hostnameVariants(host).first ?? host.name
    }
}
