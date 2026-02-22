// NetworkShareEnumerator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enumerates SMB/AFP shares via NetFS.framework — same API Finder uses.
//              Uses NetFSMountURLSync with nil mountPath to enumerate without mounting.
//              Falls back to smbutil for anonymous listing.

import Foundation
import NetFS

// MARK: - Share enumeration via NetFS (Finder-compatible)
enum NetworkShareEnumerator {

    // MARK: - Main entry: enumerate shares for a host
    // Strategy:
    //   1. NetFS with Keychain credentials (tries all hostname variants)
    //   2. NetFS anonymous / guest
    //   3. smbutil view fallback
    static func shares(for host: NetworkHost) async -> [NetworkShare] {
        let hostname = resolvedHostname(host)
        let scheme   = host.serviceType == .afp ? "afp" : "smb"

        // 1. Try with saved credentials (checks all Keychain variants)
        if let creds = NetworkAuthService.load(for: host.hostName) {
            let result = await enumerateViaNetFS(
                scheme: scheme, host: hostname,
                user: creds.user, password: creds.password
            )
            if !result.isEmpty {
                log.info("[NetFS] \(hostname): \(result.count) shares via Keychain creds (user=\(creds.user))")
                return result
            }
        }

        // Also try with base name (Finder may have stored under plain name)
        let baseName = baseName(host)
        if baseName != host.hostName {
            if let creds = NetworkAuthService.load(for: baseName) {
                let result = await enumerateViaNetFS(
                    scheme: scheme, host: hostname,
                    user: creds.user, password: creds.password
                )
                if !result.isEmpty {
                    log.info("[NetFS] \(hostname): \(result.count) shares via base-name creds (user=\(creds.user))")
                    return result
                }
            }
        }

        // 2. Anonymous / guest
        let anon = await enumerateViaNetFS(scheme: scheme, host: hostname, user: nil, password: nil)
        if !anon.isEmpty {
            log.info("[NetFS] \(hostname): \(anon.count) shares anonymously")
            return anon
        }

        // 3. smbutil fallback
        if host.serviceType != .afp {
            let smbResult = await smbUtilShares(host: host, hostname: hostname)
            if !smbResult.isEmpty {
                log.info("[smbutil] \(hostname): \(smbResult.count) shares")
                return smbResult
            }
        }

        log.info("[NetFS] \(hostname): no shares (auth required)")
        return []
    }

    // MARK: - NetFS enumeration (no mount — enumerate only)
    private static func enumerateViaNetFS(
        scheme: String, host: String,
        user: String?, password: String?
    ) async -> [NetworkShare] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                // Build URL: smb://[user@]host/
                var components = URLComponents()
                components.scheme = scheme
                components.host   = host
                components.path   = "/"
                if let u = user, !u.isEmpty { components.user = u }
                guard let url = components.url as CFURL? else {
                    cont.resume(returning: [])
                    return
                }

                // Open options
                var openDict: [String: Any] = [
                    kNetFSSoftMountKey as String: true,
                ]
                if let u = user, !u.isEmpty  { openDict[kNetFSUserNameKey as String] = u }
                if let p = password, !p.isEmpty { openDict[kNetFSPasswordKey as String] = p }
                let openOptions = Unmanaged.passRetained(openDict as CFDictionary)

                var mountOptions: Unmanaged<CFDictionary>? = nil
                var shareListRef: Unmanaged<CFArray>?       = nil

                // nil mountPath = enumerate without mounting
                let status = NetFSMountURLSync(
                    url,
                    nil,                    // mountPath — nil means enumerate only
                    user as CFString?,
                    password as CFString?,
                    openOptions,
                    &mountOptions,
                    &shareListRef
                )

                openOptions.release()
                mountOptions?.release()

                log.debug("[NetFS] \(host) enumerate status=\(status)")

                let rawList = shareListRef?.takeRetainedValue() as? [String] ?? []
                let scheme2 = scheme
                let shares: [NetworkShare] = rawList.compactMap { name in
                    guard !name.hasSuffix("$"), name != "IPC$" else { return nil }
                    let enc = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                    guard let url = URL(string: "\(scheme2)://\(host)/\(enc)") else { return nil }
                    return NetworkShare(name: name, url: url)
                }

                cont.resume(returning: shares)
            }
        }
    }

    // MARK: - smbutil view fallback
    private static func smbUtilShares(host: NetworkHost, hostname: String) async -> [NetworkShare] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let target: String
                if let creds = NetworkAuthService.load(for: host.hostName) {
                    let enc = creds.password
                        .addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? creds.password
                    target = "//\(creds.user):\(enc)@\(hostname)"
                } else {
                    target = "//\(hostname)"
                }

                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/smbutil")
                proc.arguments     = ["view", target]
                let out = Pipe(), err = Pipe()
                proc.standardOutput = out
                proc.standardError  = err

                do { try proc.run() } catch {
                    cont.resume(returning: [])
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
                    if proc.isRunning { proc.terminate() }
                }
                proc.waitUntilExit()

                let data   = out.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                log.debug("[smbutil] \(hostname) exit=\(proc.terminationStatus)\n\(output.prefix(400))")
                cont.resume(returning: parseSmbUtil(output: output, host: host, hostname: hostname))
            }
        }
    }

    // MARK: - Parse smbutil output
    private static func parseSmbUtil(output: String, host: NetworkHost, hostname: String) -> [NetworkShare] {
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
            guard !name.hasSuffix("$") else { continue }
            let scheme  = host.serviceType == .afp ? "afp" : "smb"
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            if let url = URL(string: "\(scheme)://\(hostname)/\(encoded)") {
                shares.append(NetworkShare(name: name, url: url))
            }
        }
        return shares
    }

    // MARK: - Normalize hostname for SMB connection
    static func resolvedHostname(_ host: NetworkHost) -> String {
        let hn = host.hostName
        if hn == host.name || hn == "(nil)" || hn.isEmpty {
            return host.name.hasSuffix(".local") ? host.name : "\(host.name).local"
        }
        // Strip trailing dot
        return hn.hasSuffix(".") ? String(hn.dropLast()) : hn
    }

    // MARK: - Strip .local/.fritz.box to get base name
    private static func baseName(_ host: NetworkHost) -> String {
        var n = host.hostName.isEmpty ? host.name : host.hostName
        for suffix in ["._smb._tcp.local", "._afp._tcp.local", ".local.", ".local", ".fritz.box"] {
            if n.hasSuffix(suffix) { n = String(n.dropLast(suffix.count)); break }
        }
        return n
    }
}
