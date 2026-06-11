// DropboxOAuthLoopbackServer.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Receives the Dropbox OAuth callback on a fixed loopback port.

import Foundation
import Network

// MARK: - DropboxOAuthLoopbackServer

final class DropboxOAuthLoopbackServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "Senatov.MiMiNavigator.DropboxOAuthLoopback")
    private let lock = NSLock()
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var codeContinuation: CheckedContinuation<String, Error>?
    private var didResolveCode = false
    private let expectedState: String

    // MARK: - Init

    init(expectedState: String) throws {
        guard let port = NWEndpoint.Port(rawValue: 53682) else { throw DropboxError.invalidURL(DropboxOAuthConfig.redirectURI) }
        self.expectedState = expectedState
        listener = try NWListener(using: .tcp, on: port)
    }

    // MARK: - Start

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            startContinuation = continuation
            lock.unlock()
            listener.stateUpdateHandler = { [weak self] state in self?.handleState(state) }
            listener.newConnectionHandler = { [weak self] connection in self?.handleConnection(connection) }
            listener.start(queue: queue)
        }
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

    // MARK: - State

    private func handleState(_ state: NWListener.State) {
        switch state {
        case .ready:
            resolveStart(.success(()))
        case .failed(let error):
            resolveStart(.failure(error))
            resolveCode(.failure(error))
        default:
            break
        }
    }

    // MARK: - Connection

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            self?.handleRequest(data: data, connection: connection)
        }
    }

    // MARK: - Request

    private func handleRequest(data: Data?, connection: NWConnection) {
        guard let data,
              let request = String(data: data, encoding: .utf8),
              let values = callbackValues(from: request),
              values.state == expectedState,
              let code = values.code else {
            sendResponse(connection, title: "Dropbox sign-in failed.", status: "400 Bad Request")
            resolveCode(.failure(DropboxError.missingOAuthCode))
            return
        }
        sendResponse(connection, title: "Dropbox sign-in complete. You can return to MiMiNavigator.", status: "200 OK")
        resolveCode(.success(code))
        listener.cancel()
    }

    // MARK: - Callback Values

    private func callbackValues(from request: String) -> (code: String?, state: String?)? {
        guard let firstLine = request.components(separatedBy: "\r\n").first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2,
              let components = URLComponents(string: "http://127.0.0.1\(parts[1])") else { return nil }
        let code = components.queryItems?.first { $0.name == "code" }?.value
        let state = components.queryItems?.first { $0.name == "state" }?.value
        return (code, state)
    }

    // MARK: - Response

    private func sendResponse(_ connection: NWConnection, title: String, status: String) {
        let body = "<!doctype html><html><body><p>\(title)</p></body></html>"
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Continuations

    private func resolveStart(_ result: Result<Void, Error>) {
        lock.lock()
        let continuation = startContinuation
        startContinuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

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
        continuation?.resume(with: result)
    }
}
