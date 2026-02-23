// WebUIProber.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Probes a network host for a responding HTTP/HTTPS web interface.
//   Tries 23 ports concurrently: device admin (80/443/8080/...) + dev servers (3000/5173/8000/...)
//   First responding port wins — result stored in NetworkHost.probedWebURL.
//   InsecureDelegate accepts self-signed SSL certs (common on LAN routers/NAS).
//   Called by NetworkNeighborhoodProvider.runFingerprintPass() after device classification.

import Foundation

// MARK: - WebUIProber
enum WebUIProber {

    // MARK: - Port list (in probe order — fastest/most common first)
    //
    // Tier 1 — device admin panels (routers, NAS, printers, switches)
    //   80    HTTP default
    //   443   HTTPS default
    //   8080  Alt HTTP / many embedded devices
    //   8443  Alt HTTPS
    //   631   IPP / CUPS printer admin
    //   8081  Secondary HTTP (Synology, QNAP alternate)
    //   8888  Common NAS/router alternate
    //   7070  Some NAS web managers
    //
    // Tier 2 — developer app servers (local dev, staging boxes on LAN)
    //   3000  Node.js / Express / React dev server (Create React App, Next.js)
    //   3001  Node.js alternate / Storybook
    //   4000  Phoenix (Elixir), Ruby on Rails (alt), GraphQL Playground
    //   4200  Angular CLI dev server (ng serve)
    //   5000  Flask / Python dev server, Sinatra, .NET Kestrel (old default)
    //   5001  .NET Kestrel HTTPS, Synology DSM API
    //   5173  Vite dev server (Vue, React, Svelte)
    //   8000  Django / FastAPI / Python http.server, Uvicorn default
    //   8008  Chromecast HTTP, alt HTTP
    //   8083  Some IoT / home automation (openHAB, Home Assistant alt)
    //   8123  Home Assistant
    //   9000  SonarQube, Portainer, PHP-FPM debug
    //   9090  Prometheus, Cockpit (Linux server web UI)

    static let candidatePorts: [Int] = [
        // Tier 1 — device admin
        80, 443, 8080, 8443, 631, 8081, 8888, 7070,
        // Tier 2 — developer app servers
        3000, 3001, 4000, 4200, 5000, 5001, 5173,
        8000, 8008, 8083, 8123, 9000, 9090,
    ]

    // MARK: - Probe host — returns first responding URL or nil
    // Fires all requests concurrently with a short timeout; returns first 2xx/3xx response.
    @concurrent static func probe(host: NetworkHost) async -> URL? {
        let ip = bestAddress(host)
        guard !ip.isEmpty else { return nil }

        // Already has a static web URL (router/printer) — just verify it responds
        if let staticURL = host.webUIURL {
            if await responds(url: staticURL) { return staticURL }
        }

        // Probe all candidate ports concurrently
        return await withTaskGroup(of: URL?.self) { group in
            for port in candidatePorts {
                let scheme = (port == 443 || port == 8443 || port == 5001) ? "https" : "http"
                guard let url = URL(string: "\(scheme)://\(ip):\(port)") else { continue }
                group.addTask { @concurrent in await responds(url: url) ? url : nil }
            }
            // Return first non-nil result, cancel remaining tasks
            for await result in group {
                if let url = result {
                    group.cancelAll()
                    return url
                }
            }
            return nil
        }
    }

    // MARK: - Quick TCP/HTTP reachability check (1.5s timeout)
    @concurrent static func responds(url: URL) async -> Bool {
        var req = URLRequest(url: url, timeoutInterval: 1.5)
        req.httpMethod = "HEAD"
        // Ignore SSL errors for LAN devices with self-signed certs
        let session = URLSession(configuration: .ephemeral,
                                 delegate: InsecureDelegate.shared,
                                 delegateQueue: nil)
        guard let (_, resp) = try? await session.data(for: req) else { return false }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return (200...399).contains(code)
    }

    // MARK: - Best address to probe (prefer DNS name, fall back to IP)
    private static func bestAddress(_ host: NetworkHost) -> String {
        // Use hostName if it's a proper DNS name (not MAC@addr, not empty)
        let hn = host.hostName
        if !hn.isEmpty && hn != "(nil)" && !hn.contains("@") && !hn.contains(":") {
            return hn
        }
        // Fall back to IP from FritzBox
        if !host.hostIP.isEmpty { return host.hostIP }
        // Last resort: try hostDisplayName (may be IP-like 192-168-x-x)
        let d = host.hostDisplayName
        if d.contains(".") { return d }
        return ""
    }
}

// MARK: - InsecureDelegate: accept self-signed certs on LAN devices
// Many routers/NAS boxes use self-signed HTTPS — without this all HTTPS probes fail.
private final class InsecureDelegate: NSObject, URLSessionDelegate {
    static let shared = InsecureDelegate()
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
