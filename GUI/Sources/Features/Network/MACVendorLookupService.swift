// MACVendorLookupService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Rate-limited MAC manufacturer lookup with an in-memory cache.

import Foundation

// MARK: - MAC Vendor Lookup Service
actor MACVendorLookupService {
    static let shared = MACVendorLookupService()
    private var cache: [String: String] = [:]
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 7
        session = URLSession(configuration: configuration)
    }

    // MARK: - Manufacturer Lookup
    func manufacturer(for macAddress: String) async -> String? {
        guard let normalizedMAC = normalized(macAddress) else { return nil }
        if let cached = cache[normalizedMAC] { return cached.isEmpty ? nil : cached }
        guard let encodedMAC = normalizedMAC.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://api.macvendors.com/\(encodedMAC)")
        else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            if httpResponse.statusCode == 404 {
                cache[normalizedMAC] = ""
                return nil
            }
            guard httpResponse.statusCode == 200,
                let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !value.isEmpty
            else {
                log.debug("[NetworkVendor] lookup failed status=\(httpResponse.statusCode)")
                return nil
            }
            cache[normalizedMAC] = value
            return value
        } catch {
            log.debug("[NetworkVendor] lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Normalize MAC Address
    private func normalized(_ value: String) -> String? {
        let hex = value.filter(\.isHexDigit).uppercased()
        guard hex.count == 12 else { return nil }
        return stride(from: 0, to: 12, by: 2)
            .map { index in
                let start = hex.index(hex.startIndex, offsetBy: index)
                let end = hex.index(start, offsetBy: 2)
                return String(hex[start..<end])
            }
            .joined(separator: ":")
    }
}
