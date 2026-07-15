// FingLocalAPIClient.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Optional client and Keychain-backed settings for Fing Local API.

import Foundation
import Security

// MARK: - Fing Device
struct FingDevice: Decodable, Sendable {
    let mac: String
    let ip: [String]
    let state: String
    let name: String?
    let type: String?
    let make: String?
    let model: String?
}

// MARK: - Fing Devices Response
private struct FingDevicesResponse: Decodable {
    let devices: [FingDevice]
}

// MARK: - Fing Local API Error
enum FingLocalAPIError: LocalizedError {
    case disabled
    case missingAPIKey
    case invalidPort
    case invalidResponse
    case unauthorized
    case serviceUnavailable
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
            case .disabled: return "Fing Local API is disabled."
            case .missingAPIKey: return "Enter the Fing Local API key."
            case .invalidPort: return "The Fing Local API port is invalid."
            case .invalidResponse: return "Fing returned an invalid response."
            case .unauthorized: return "Fing rejected the API key."
            case .serviceUnavailable: return "Fing Desktop or Fing Agent is unavailable."
            case .httpStatus(let status): return "Fing returned HTTP \(status)."
        }
    }
}

// MARK: - Fing Local API Settings
enum FingLocalAPISettings {
    private static let enabledKey = "network.fing.enabled"
    private static let portKey = "network.fing.port"
    private static let keychainService = "Senatov.MiMiNavigator.FingLocalAPI"
    private static let keychainAccount = "local-api-key"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var port: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: portKey)
            return stored == 0 ? 49_090 : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: portKey) }
    }

    static func loadAPIKey() -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationUI: kSecUseAuthenticationUISkip
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else { return "" }
        return value
    }

    static func saveAPIKey(_ value: String) {
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        guard !value.isEmpty else { return }
        var addQuery = deleteQuery
        addQuery[kSecValueData] = Data(value.utf8)
        addQuery[kSecAttrLabel] = "MiMiNavigator Fing Local API"
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess { log.warning("[Fing] Keychain save failed: \(status)") }
    }
}

// MARK: - Fing Local API Client
actor FingLocalAPIClient {
    static let shared = FingLocalAPIClient()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        session = URLSession(configuration: configuration)
    }

    // MARK: - Fetch Devices
    func fetchDevices() async throws -> [FingDevice] {
        guard FingLocalAPISettings.isEnabled else { throw FingLocalAPIError.disabled }
        let apiKey = FingLocalAPISettings.loadAPIKey()
        guard !apiKey.isEmpty else { throw FingLocalAPIError.missingAPIKey }
        let port = FingLocalAPISettings.port
        guard (1...65_535).contains(port) else { throw FingLocalAPIError.invalidPort }
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = port
        components.path = "/1/devices"
        components.queryItems = [URLQueryItem(name: "auth", value: apiKey)]
        guard let url = components.url else { throw FingLocalAPIError.invalidPort }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else { throw FingLocalAPIError.invalidResponse }
        switch httpResponse.statusCode {
            case 200: break
            case 401: throw FingLocalAPIError.unauthorized
            case 503: throw FingLocalAPIError.serviceUnavailable
            default: throw FingLocalAPIError.httpStatus(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(FingDevicesResponse.self, from: data).devices
    }
}
