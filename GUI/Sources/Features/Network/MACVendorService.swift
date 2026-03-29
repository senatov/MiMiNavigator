// MACVendorService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: MAC vendor lookup via api.macvendors.com (free, no key).
//   Actor-isolated, cached, rate-limited (1 req/sec).
//   Extracted from NetworkDeviceInfoPopup.swift.

import Foundation

// MARK: - MACVendorService
actor MACVendorService {
    static let shared = MACVendorService()

    private var cache: [String: String] = [:]
    private var temporaryFailures: [String: Date] = [:]
    private var localOUIVendors: [String: String] = [:]
    private var didLoadLocalOUIVendors = false
    private var lastRequestTime: Date?

    private let minRequestInterval: TimeInterval = 1.0
    private let requestTimeout: TimeInterval = 3.0
    private let temporaryFailureTTL: TimeInterval = 15.0

    private let invalidMACText = "Invalid MAC"
    private let unknownVendorText = "Unknown vendor"
    private let networkErrorText = "Network error"
    private let rateLimitText = "Rate limit exceeded"

    func lookup(_ mac: String) async -> String {
        guard let prefix = normalizePrefix(from: mac) else {
            log.debug("[MACVendor] invalid MAC input")
            return invalidMACText
        }

        if let cachedVendor = cache[prefix] {
            log.debug("[MACVendor] cache hit prefix=\(prefix)")
            return cachedVendor
        }

        if let temporaryFailureResult = temporaryFailureResult(for: prefix) {
            log.debug("[MACVendor] temporary failure cache hit prefix=\(prefix)")
            return temporaryFailureResult
        }

        if let localVendor = await localVendor(prefix: prefix) {
            log.debug("[MACVendor] local OUI hit prefix=\(prefix)")
            cache[prefix] = localVendor
            return localVendor
        }

        await respectRateLimitIfNeeded()

        guard let request = makeRequest(prefix: prefix) else {
            log.error("[MACVendor] failed to build request prefix=\(prefix)")
            return invalidMACText
        }

        lastRequestTime = Date()
        log.debug("[MACVendor] request start prefix=\(prefix)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let vendor = handleResponse(data: data, response: response, prefix: prefix)
            log.debug("[MACVendor] request done prefix=\(prefix)")
            return vendor
        } catch {
            log.error("[MACVendor] request failed prefix=\(prefix)")
            log.error("[MACVendor] error=\(error.localizedDescription)")
            rememberTemporaryFailure(for: prefix)
            return networkErrorText
        }
    }

    private func temporaryFailureResult(for prefix: String) -> String? {
        guard let expiry = temporaryFailures[prefix] else { return nil }

        if expiry <= Date() {
            temporaryFailures[prefix] = nil
            return nil
        }

        return networkErrorText
    }

    private func rememberTemporaryFailure(for prefix: String) {
        temporaryFailures[prefix] = Date().addingTimeInterval(temporaryFailureTTL)
    }

    private func clearTemporaryFailure(for prefix: String) {
        temporaryFailures[prefix] = nil
    }

    private func localVendor(prefix: String) async -> String? {
        loadLocalOUIVendorsIfNeeded()
        return localOUIVendors[prefix]
    }

    private func loadLocalOUIVendorsIfNeeded() {
        guard !didLoadLocalOUIVendors else { return }
        didLoadLocalOUIVendors = true

        guard let url = Bundle.main.url(forResource: "oui-vendors", withExtension: "txt") else {
            log.debug("[MACVendor] oui-vendors.txt not found in bundle")
            return
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            parseLocalOUIVendors(content)
            log.info("[MACVendor] local OUI prefixes loaded=\(localOUIVendors.count)")
        } catch {
            log.error("[MACVendor] failed to load oui-vendors.txt")
            log.error("[MACVendor] error=\(error.localizedDescription)")
        }
    }

    private func parseLocalOUIVendors(_ content: String) {
        let lines = content.components(separatedBy: .newlines)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard !line.hasPrefix("#") else { continue }

            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let prefix = parts[0]
                .uppercased()
                .filter { $0.isHexDigit }

            guard prefix.count == 6 else { continue }

            let vendor = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !vendor.isEmpty else { continue }

            localOUIVendors[prefix] = vendor
        }
    }

    private func normalizePrefix(from mac: String) -> String? {
        let filtered = mac
            .uppercased()
            .filter { $0.isHexDigit }

        guard filtered.count >= 6 else { return nil }

        let prefix = String(filtered.prefix(6))
        guard prefix.count == 6 else { return nil }
        return prefix
    }

    private func respectRateLimitIfNeeded() async {
        guard let lastRequestTime else { return }

        let elapsed = Date().timeIntervalSince(lastRequestTime)
        guard elapsed < minRequestInterval else { return }

        let delay = minRequestInterval - elapsed
        let delayInNanoseconds = UInt64(delay * 1_000_000_000)
        log.debug("[MACVendor] rate limit sleep ns=\(delayInNanoseconds)")
        try? await Task.sleep(nanoseconds: delayInNanoseconds)
    }

    private func makeRequest(prefix: String) -> URLRequest? {
        guard let url = URL(string: "https://api.macvendors.com/\(prefix)") else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue("MiMiNavigator/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func handleResponse(data: Data, response: URLResponse, prefix: String) -> String {
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        log.debug("[MACVendor] status prefix=\(prefix) code=\(statusCode)")

        switch statusCode {
            case 200:
                clearTemporaryFailure(for: prefix)
                return handleSuccessResponse(data: data, prefix: prefix)
            case 404:
                clearTemporaryFailure(for: prefix)
                cache[prefix] = unknownVendorText
                return unknownVendorText
            case 429:
                rememberTemporaryFailure(for: prefix)
                return rateLimitText
            default:
                rememberTemporaryFailure(for: prefix)
                return "API error (\(statusCode))"
        }
    }

    private func handleSuccessResponse(data: Data, prefix: String) -> String {
        guard let vendor = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !vendor.isEmpty
        else {
            cache[prefix] = unknownVendorText
            return unknownVendorText
        }

        cache[prefix] = vendor
        return vendor
    }
}
