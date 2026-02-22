// NetworkShareEnumerator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enumerates SMB/AFP shares via NetFS.framework — same API Finder uses.
//              Falls back to smbutil for anonymous listing if NetFS fails.

import Foundation
import NetFS

// MARK: - Share enumeration via NetFS (Finder-compatible)
enum NetworkShareEnumerator {

    // MARK: - Enumerate shares for a host, returns share names
    // Strategy:
    //   1. NetFS with Keychain credentials (same as Finder)
    //   2. NetFS anonymous / guest
    //   3. smbutil view fallback
    static func shares(for host: NetworkHost) async -> [NetworkShare] {
        let hostname = resolvedHostname(host)
        let scheme   = host.serviceType == .afp ? "afp" : "smb"

        // 1. NetFS with saved credentials
        if let creds = NetworkAuthService.load(for: host.hostName) {
            let result = await netfsShares(scheme: scheme, host: hostname,
                                           user: creds.user, password: creds.password)
            if !result.isEmpty {
                log.info("[NetFS] got \(result.count) shares for \(hostname) via saved creds")
                return result
            }
        }

        // 2. NetFS anonymous / guest
        let anonymous = await netfsShares(scheme: scheme, host: hostname, user: nil, password: nil)
        if !anonymous.isEmpty {
            log.info("[NetFS] got \(anonymous.count) shares for \(hostname) anonymously")
            return anonymous
        }

        // 3. smbutil fallback (works without auth on some hosts)
        if host.serviceType == .smb {
            let smbResult = await smbUtilShares(host: host, hostname: hostname)
            if !smbResult.isEmpty {
                log.info("[smbutil] got \(smbResult.count) shares for \(hostname)")
                return smbResult
            }
        }

        log.info("[NetFS] no shares found for \(hostname) — auth required")
        return []
    }

    // MARK: - NetFS enumeration (async wrapper)
    private static func netfsShares(
        scheme: String, host: String,
        user: String?, password: String?
    ) async -> [NetworkShare] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard var urlComponents = URLComponents() as URLComponents? else {
                    continuation.resume(returning: [])
                    return
                }
                urlComponents.scheme = scheme
                urlComponents.host   = host
                urlComponents.path   = "/"
                if let u = user { urlComponents.user = u }

                guard let url = urlComponents.url as CFURL? else {
                    continuation.resume(returning: [])
                    return
                }

                var mountOptions: Unmanaged<CFDictionary>? = nil
                var openOptions: Unmanaged<CFDictionary>? = nil

                // Build options dict
                var opts: [String: Any] = [
                    kNetFSAllowLoopbackKey as String: false,
                    kNetFSSoftMountKey as String: true,
                ]
                if let u = user {
                    opts[kNetFSUserNameKey as String] = u
                }
                if let p = password {
                    opts[kNetFSPasswordKey as String] = p
                }
                openOptions = Unmanaged.passRetained(opts as CFDictionary)

                var shareList: Unmanaged<CFArray>? = nil

                let status = NetFSMountURLSync(
                    url,
                    nil,        // mountpoint nil = enumerate only
                    user as CFString?,
                    password as CFString?,
                    openOptions,
                    &mountOptions,
                    &shareList
                )

                openOptions?.release()
                mountOptions?.release()

                guard status == 0 || status == -6003, // -6003 = already mounted
                      let rawList = shareList?.takeRetainedValue() as? [String]
                else {
                    log.debug("[NetFS] enumerate status=\(status) host=\(host)")
                    shareList?.release()
                    continuation.resume(returning: [])
                    return
                }

                let scheme2 = scheme
                let shares: [NetworkShare] = rawList.compactMap { name in
                    // Skip system/hidden shares
                    guard !name.hasSuffix("$") && name != "IPC$" else { return nil }
                    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                    guard let url = URL(string: "\(scheme2)://\(host)/\(encoded)") else { return nil }
                    return NetworkShare(name: name, url: url)
                }
                continuation.resume(returning: shares)
            }
        }
    }

    // MARK: - smbutil view fallback
    private static func smbUtilShares(host: NetworkHost, hostname: String) async -> [NetworkShare] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let target: String
                if let creds = NetworkAuthService.load(for: host.hostName) {
                    let enc = creds.password
                        .addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? creds.password
                    target = "//\(creds.user):\(enc)@\(hostname)"
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
                    continuation.resume(returning: [])
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
                    if process.isRunning { process.terminate() }
                }
                process.waitUntilExit()
                let data   = outPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                log.debug("[smbutil] \(hostname) exit=\(process.terminationStatus) output=\(output.prefix(300))")
                let shares = parseSmbUtil(output: output, host: host, hostname: hostname)
                continuation.resume(returning: shares)
            }
        }
    }

    // MARK: - Parse smbutil view output
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

    // MARK: - Normalize hostname: prefer .local, fallback
    static func resolvedHostname(_ host: NetworkHost) -> String {
        let hn = host.hostName
        if hn == host.name || hn == "(nil)" || hn.isEmpty {
            return host.name.hasSuffix(".local") ? host.name : "\(host.name).local"
        }
        return hn
    }
}
