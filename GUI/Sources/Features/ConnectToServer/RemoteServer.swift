// RemoteServer.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model for saved remote server connections (SFTP / FTP / SMB / AFP).
//   Codable for JSON persistence. Password stored in Keychain, not in JSON.

import Foundation

// MARK: - Protocol type for remote connection
enum RemoteProtocol: String, Codable, CaseIterable, Identifiable {
    case sftp = "SFTP"
    case ftp  = "FTP"
    case smb  = "SMB"
    case afp  = "AFP"

    var id: String { rawValue }

    var defaultPort: Int {
        switch self {
        case .sftp: return 22
        case .ftp:  return 21
        case .smb:  return 445
        case .afp:  return 548
        }
    }

    var urlScheme: String {
        switch self {
        case .sftp: return "sftp"
        case .ftp:  return "ftp"
        case .smb:  return "smb"
        case .afp:  return "afp"
        }
    }
}

// MARK: - Authentication method
enum RemoteAuthType: String, Codable, CaseIterable, Identifiable {
    case password   = "Password"
    case privateKey = "Private Key"
    case agent      = "Agent"

    var id: String { rawValue }
}

// MARK: - Connection result status
enum ConnectionResult: String, Codable {
    case none       = "—"
    case success    = "OK"
    case authFailed = "Auth Failed"
    case timeout    = "Timeout"
    case refused    = "Refused"
    case error      = "Error"

    var icon: String {
        switch self {
        case .none:       return "minus.circle"
        case .success:    return "checkmark.circle.fill"
        case .authFailed: return "lock.slash"
        case .timeout:    return "clock.badge.exclamationmark"
        case .refused:    return "xmark.circle"
        case .error:      return "exclamationmark.triangle"
        }
    }
}

// MARK: - Saved remote server entry
struct RemoteServer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var user: String
    var port: Int
    var remoteProtocol: RemoteProtocol
    var remotePath: String
    var authType: RemoteAuthType
    var privateKeyPath: String
    var connectOnStart: Bool
    var lastConnected: Date?
    var lastResult: ConnectionResult

    // Password is NOT stored here — it lives in Keychain
    // Use RemoteServerKeychain.loadPassword(for:) / savePassword(_:for:)

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        user: String = "",
        port: Int = 22,
        remoteProtocol: RemoteProtocol = .sftp,
        remotePath: String = "",
        authType: RemoteAuthType = .password,
        privateKeyPath: String = "~/.ssh/id_rsa",
        connectOnStart: Bool = false,
        lastConnected: Date? = nil,
        lastResult: ConnectionResult = .none
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.remoteProtocol = remoteProtocol
        self.remotePath = remotePath
        self.authType = authType
        self.privateKeyPath = privateKeyPath
        self.connectOnStart = connectOnStart
        self.lastConnected = lastConnected
        self.lastResult = lastResult
    }

    // MARK: - Build connection URL (without password — password added at connect time)
    var connectionURL: URL? {
        var c = URLComponents()
        c.scheme = remoteProtocol.urlScheme
        c.host = host
        if !user.isEmpty { c.user = user }
        if port != remoteProtocol.defaultPort { c.port = port }
        if !remotePath.isEmpty {
            c.path = remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        } else {
            c.path = "/"
        }
        return c.url
    }

    // MARK: - Display label for sidebar
    var displayName: String {
        name.isEmpty ? host : name
    }

    // MARK: - Summary line for Recent table
    var sessionSummary: String {
        let proto = remoteProtocol.rawValue
        let portStr = port != remoteProtocol.defaultPort ? ":\(port)" : ""
        return "\(proto) \(user.isEmpty ? "" : "\(user)@")\(host)\(portStr)"
    }

    // MARK: - Formatted last-connected date
    var formattedLastConnected: String {
        guard let date = lastConnected else { return "—" }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
