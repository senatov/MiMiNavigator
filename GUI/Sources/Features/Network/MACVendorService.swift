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
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 1.0



    func lookup(_ mac: String) async -> String {
        let prefix = mac.replacingOccurrences(of: ":", with: "").prefix(6).uppercased()
        if let cached = cache[String(prefix)] {
            return cached
        }
        if let last = lastRequestTime {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minRequestInterval {
                try? await Task.sleep(nanoseconds: UInt64((minRequestInterval - elapsed) * 1_000_000_000))
            }
        }
        guard let url = URL(string: "https://api.macvendors.com/" + prefix) else {
            return "Invalid MAC"
        }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.setValue("MiMiNavigator/1.0", forHTTPHeaderField: "User-Agent")
        lastRequestTime = Date()
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let httpResp = resp as? HTTPURLResponse
            switch httpResp?.statusCode {
            case 200:
                if let vendor = String(data: data, encoding: .utf8), !vendor.isEmpty {
                    cache[String(prefix)] = vendor
                    return vendor
                }
                return "Unknown"
            case 404:
                cache[String(prefix)] = "Unknown vendor"
                return "Unknown vendor"
            case 429:
                return "Rate limit exceeded"
            default:
                return "API error (\(httpResp?.statusCode ?? 0))"
            }
        } catch {
            return "Network error"
        }
    }
}
