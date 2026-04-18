// WebUIProber.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Probes a network host for a reachable HTTP/HTTPS web interface.
//   Tries common admin, device, and developer ports concurrently.
//   The first responding endpoint wins and becomes NetworkHost.probedWebURL.

import Foundation

// MARK: - Web UI Prober
enum WebUIProber {

    private enum ProbeOutcome {
        case success(method: String, statusCode: Int)
        case failure(String)
    }

    private static let requestTimeoutSeconds: TimeInterval = 1.5
    private static let httpsPorts: Set<Int> = [443, 8443, 5001]
    private static let getFallbackRangeHeader = "bytes=0-0"
    private static let logPreviewLength = 120
    private static let staticURLVerificationLogPrefix = "[WebUI] static"
    private static let probeLogPrefix = "[WebUI] probe"
    private static let infrastructurePorts: [Int] = [80, 443, 8080, 8443, 631, 8081, 8888, 7070, 5001]
    private static let developerPorts: [Int] = [3000, 3001, 4000, 4200, 5000, 5173, 8000, 8008, 8083, 8123, 9000, 9090]
    private static let mobilePorts: [Int] = [80, 443, 8443]
    private static let defaultCandidatePorts = infrastructurePorts + developerPorts

    private static func scheme(for port: Int) -> String {
        httpsPorts.contains(port) ? "https" : "http"
    }

    private static func candidateURL(host: String, port: Int) -> URL? {
        URL(string: "\(scheme(for: port))://\(host):\(port)")
    }

    private static func normalizedURLString(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isUsableAddress(_ value: String) -> Bool {
        let normalizedValue = normalizedAddressCandidate(value)
        return !normalizedValue.isEmpty && normalizedValue != "(nil)"
    }

    private static func normalizedAddressCandidate(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func statusCode(from response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    private static func headRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: requestTimeoutSeconds)
        request.httpMethod = "HEAD"
        return request
    }

    private static func fallbackGetRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: requestTimeoutSeconds)
        request.httpMethod = "GET"
        request.setValue(getFallbackRangeHeader, forHTTPHeaderField: "Range")
        return request
    }

    private static let probeSession: URLSession = {
        URLSession(
            configuration: .ephemeral,
            delegate: InsecureDelegate.shared,
            delegateQueue: nil
        )
    }()

    private static func shouldUseHostName(_ hostName: String) -> Bool {
        let normalizedHostName = normalizedAddressCandidate(hostName)
        return !normalizedHostName.isEmpty
            && normalizedHostName != "(nil)"
            && !normalizedHostName.contains("@")
            && !normalizedHostName.contains(":")
    }

    private static func shouldUseDisplayName(_ displayName: String) -> Bool {
        let normalizedDisplayName = normalizedAddressCandidate(displayName)
        return isUsableAddress(normalizedDisplayName) && normalizedDisplayName.contains(".")
    }

    private static func isSuccessfulStatusCode(_ statusCode: Int) -> Bool {
        (200...399).contains(statusCode)
    }

    private static func logStaticURLVerificationStart(_ url: URL) {
        log.debug("\(staticURLVerificationLogPrefix) verify url=\(normalizedURLString(url.absoluteString))")
    }

    private static func logProbeStart(hostName: String, address: String, candidateCount: Int) {
        log.debug("\(probeLogPrefix) host='\(hostName)' address='\(address)' candidates=\(candidateCount)")
    }

    private static func logProbeSuccess(hostName: String, url: URL, method: String, statusCode: Int, candidateCount: Int) {
        log.info(
            "\(probeLogPrefix) '\(hostName)' hit url=\(normalizedURLString(url.absoluteString)) method=\(method) code=\(statusCode) candidates=\(candidateCount)"
        )
    }

    private static func logProbeFailure(hostName: String, candidateCount: Int, details: String) {
        let preview = details.prefix(logPreviewLength)
        log.debug("\(probeLogPrefix) '\(hostName)' no hit after \(candidateCount) candidates reason=\(preview)")
    }

    private static func candidatePorts(for host: NetworkHost) -> [Int] {
        if host.deviceClass.isMobile {
            return mobilePorts
        }

        switch host.deviceClass {
        case .router, .printer, .repeater, .networkSwitch, .camera, .nas:
            return infrastructurePorts
        case .mediaBox, .smartTV, .gameConsole:
            return infrastructurePorts + [8123, 8083, 8000]
        case .mac, .windowsPC, .linuxServer, .unknown, .androidPhone, .androidTablet, .iPhone, .iPad:
            return defaultCandidatePorts
        }
    }

    private static func bestAddress(_ host: NetworkHost) -> String {
        let hostName = normalizedAddressCandidate(host.hostName)
        if shouldUseHostName(hostName) {
            return hostName
        }

        let hostIP = normalizedAddressCandidate(host.hostIP)
        if isUsableAddress(hostIP) {
            return hostIP
        }

        let displayName = normalizedAddressCandidate(host.hostDisplayName)
        if shouldUseDisplayName(displayName) {
            return displayName
        }

        return ""
    }

    private static func verifiedStaticWebURLOrNil(for host: NetworkHost) async -> URL? {
        guard let staticURL = host.webUIURL else { return nil }
        logStaticURLVerificationStart(staticURL)
        if case .success = await responds(url: staticURL) {
            return staticURL
        }
        return nil
    }

    // MARK: - Probe host — returns first responding URL or nil
    // Fires all requests concurrently with a short timeout; returns first 2xx/3xx response.
    @concurrent static func probe(host: NetworkHost) async -> URL? {
        let address = bestAddress(host)
        guard !address.isEmpty else { return nil }

        // Already has a static web URL (router/printer) — just verify it responds
        if let staticURL = await verifiedStaticWebURLOrNil(for: host) {
            log.info("\(probeLogPrefix) '\(host.name)' static url=\(normalizedURLString(staticURL.absoluteString))")
            return staticURL
        }

        let ports = candidatePorts(for: host)
        logProbeStart(hostName: host.name, address: address, candidateCount: ports.count)

        // Probe all candidate ports concurrently
        return await withTaskGroup(of: (URL, ProbeOutcome).self) { @concurrent group in
            var firstFailureDetail: String?
            for port in ports {
                guard let url = candidateURL(host: address, port: port) else { continue }
                group.addTask { @concurrent in
                    (url, await responds(url: url))
                }
            }
            // Return first non-nil result, cancel remaining tasks
            for await (url, outcome) in group {
                if case let .success(method, statusCode) = outcome {
                    group.cancelAll()
                    logProbeSuccess(
                        hostName: host.name,
                        url: url,
                        method: method,
                        statusCode: statusCode,
                        candidateCount: ports.count
                    )
                    return url
                }
                if case let .failure(details) = outcome, firstFailureDetail == nil {
                    firstFailureDetail = details
                }
            }
            logProbeFailure(
                hostName: host.name,
                candidateCount: ports.count,
                details: firstFailureDetail ?? "no HTTP response on preferred ports"
            )
            return nil
        }
    }

    // MARK: - Reachability Check
    @concurrent private static func responds(url: URL) async -> ProbeOutcome {
        let headRequest = headRequest(for: url)

        if let (_, response) = try? await probeSession.data(for: headRequest) {
            let statusCode = statusCode(from: response)
            if isSuccessfulStatusCode(statusCode) {
                return .success(method: "HEAD", statusCode: statusCode)
            }
        }

        let getRequest = fallbackGetRequest(for: url)

        if let (_, response) = try? await probeSession.data(for: getRequest) {
            let statusCode = statusCode(from: response)
            if isSuccessfulStatusCode(statusCode) {
                return .success(method: "GET", statusCode: statusCode)
            }
            return .failure("GET status=\(statusCode)")
        }

        return .failure("no HTTP response")
    }

    // MARK: - Candidate Ports
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
}

// MARK: - InsecureDelegate
// Accepts self-signed certificates for LAN device probing.
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
