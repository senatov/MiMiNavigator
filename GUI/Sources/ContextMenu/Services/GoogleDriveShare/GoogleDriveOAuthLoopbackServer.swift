// GoogleDriveOAuthLoopbackServer.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Local OAuth callback listener for Google desktop OAuth flow.

import Foundation
import Network

// MARK: - GoogleDriveOAuthLoopbackServer

final class GoogleDriveOAuthLoopbackServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "Senatov.MiMiNavigator.GoogleDriveOAuthLoopback")
    private let lock = NSLock()
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var codeContinuation: CheckedContinuation<String, Error>?
    private var didResolveCode = false

    var redirectURI: String {
        guard let port = listener.port else { return "http://127.0.0.1/oauth2callback" }
        return "http://127.0.0.1:\(port.rawValue)/oauth2callback"
    }

    // MARK: - Init

    init() throws {
        guard let anyPort = NWEndpoint.Port(rawValue: 0) else { throw GoogleDriveError.missingLoopbackPort }
        listener = try NWListener(using: .tcp, on: anyPort)
    }

    // MARK: - Start

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            startContinuation = continuation
            lock.unlock()
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleState(state)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener.start(queue: queue)
        }
        guard listener.port != nil else { throw GoogleDriveError.missingLoopbackPort }
    }

    // MARK: - Wait For Code

    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            codeContinuation = continuation
            lock.unlock()
        }
    }

    // MARK: - Cancel

    func cancel() {
        listener.cancel()
    }

    // MARK: - State Handler

    private func handleState(_ state: NWListener.State) {
        switch state {
        case .ready:
            resolveStart(.success(()))
        case .failed(let error):
            resolveStart(.failure(error))
            resolveCode(.failure(error))
        case .cancelled:
            break
        default:
            break
        }
    }

    // MARK: - Connection Handler

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            self?.handleRequest(data: data, connection: connection)
        }
    }

    // MARK: - Request Handler

    private func handleRequest(data: Data?, connection: NWConnection) {
        guard let data, let request = String(data: data, encoding: .utf8) else {
            sendResponse(connection, title: "Google Drive sign-in failed.", status: "400 Bad Request")
            resolveCode(.failure(GoogleDriveError.missingOAuthCode))
            return
        }
        guard let code = parseCode(from: request) else {
            sendResponse(connection, title: "Google Drive sign-in failed.", status: "400 Bad Request")
            resolveCode(.failure(GoogleDriveError.missingOAuthCode))
            return
        }
        sendResponse(connection, title: "Google Drive sign-in complete. You can return to MiMiNavigator.", status: "200 OK")
        resolveCode(.success(code))
        listener.cancel()
    }

    // MARK: - Parse Code

    private func parseCode(from request: String) -> String? {
        guard let firstLine = request.components(separatedBy: "\r\n").first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        guard let components = URLComponents(string: "http://127.0.0.1\(parts[1])") else { return nil }
        return components.queryItems?.first { $0.name == "code" }?.value
    }

    // MARK: - Send Response

    private func sendResponse(_ connection: NWConnection, title: String, status: String) {
        let body = "<!doctype html><html><body><p>\(title)</p></body></html>"
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Resolve Start

    private func resolveStart(_ result: Result<Void, Error>) {
        lock.lock()
        let continuation = startContinuation
        startContinuation = nil
        lock.unlock()
        switch result {
        case .success:
            continuation?.resume()
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    // MARK: - Resolve Code

    private func resolveCode(_ result: Result<String, Error>) {
        lock.lock()
        guard didResolveCode == false else {
            lock.unlock()
            return
        }
        didResolveCode = true
        let continuation = codeContinuation
        codeContinuation = nil
        lock.unlock()
        switch result {
        case .success(let code):
            continuation?.resume(returning: code)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}
