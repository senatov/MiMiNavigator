//
//  ConnToSrvrView+Actions.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Actions
extension ConnToSrvrView {

    func handleAppear() {
        restoreSidebarWidth()
        applyPendingFocusOrSelectFirst()
    }

    func handleSelectionChange(_ newID: RemoteServer.ID?) {
        connectionError = ""
        ConnectErrorPopupController.shared.hide()
        guard let id = newID,
            let server = store.servers.first(where: { $0.id == id })
        else {
            return
        }
        applyServerToDraft(server)
        log.debug("\(#function) switched to server '\(server.displayName)'")
    }

    func connectAction() {
        saveAction()
        silentExport()
        connectionError = ""

        guard let url = draft.connectionURL else {
            connectionError = "Invalid URL"
            log.warning("[ConnToSrvr] invalid URL for '\(draft.host)'")
            return
        }

        logConnectionAttempt(url: url)

        if reuseExistingConnectionIfPossible(url: url) {
            return
        }

        startConnection(for: url)
    }

    func finishRemoteConnect(url: URL) async {
        await connectionManager.connect(to: draft, password: password)
        guard !Task.isCancelled else {
            isConnecting = false
            return
        }
        log.debug("[ConnToSrvr] connect() finished, isConnected=\(connectionManager.isConnected)")

        if connectionManager.isConnected(to: draft) {
            handleConnectionSuccess(url: url)
            return
        }

        handleConnectionFailure()
    }

    func focusFieldForError(_ result: ConnectionResult) {
        switch result {
            case .authFailed:
                focusedField = .password
            case .refused, .timeout:
                focusedField = .host
            default:
                break
        }
    }

    func saveAction() {
        log.debug("[ConnToSrvr] saveAction host=\(draft.host) id=\(draft.id)")

        if draft.name.isEmpty {
            draft.name = draft.host
        }

        persistPasswordIfNeeded()
        persistDraftBookmark()

        selectedID = draft.id
        log.info("[ConnToSrvr] bookmark saved host=\(draft.host) id=\(draft.id)")
    }

    func disconnectAction() {
        guard canDisconnectCurrentDraft else {
            log.debug("[ConnToSrvr] disconnect ignored")
            log.debug("[ConnToSrvr] current draft is not actively connected")
            return
        }

        guard let connection = connectionManager.connection(for: draft) else {
            log.debug("[ConnToSrvr] disconnect ignored")
            log.debug("[ConnToSrvr] no connection object for current draft")
            return
        }

        log.info("[ConnToSrvr] disconnecting from \(draft.host)")
        Task {
            await connectionManager.disconnect(id: connection.id)
            onDisconnect?()
        }
    }

    func deleteServerAction(server: RemoteServer) {
        if let connection = connectionManager.connection(for: server) {
            Task {
                await connectionManager.disconnect(id: connection.id)
            }
        }

        RemoteServerKeychain.deletePassword(for: server)
        store.remove(server)
        onDisconnect?()
        selectFirst()
        log.info("[ConnToSrvr] deleted server \(server.displayName)")
    }

    func connectServerAction(server: RemoteServer) {
        applyServerToDraft(server)
        selectedID = server.id
        connectAction()
    }

    func disconnectServerAction(server: RemoteServer) {
        guard connectionManager.isConnected(to: server) else {
            log.debug("[ConnToSrvr] server disconnect ignored")
            log.debug("[ConnToSrvr] server is not connected: \(server.displayName)")
            return
        }

        guard let connection = connectionManager.connection(for: server) else {
            log.debug("[ConnToSrvr] server disconnect ignored")
            log.debug("[ConnToSrvr] no connection object for server: \(server.displayName)")
            return
        }

        Task {
            await connectionManager.disconnect(id: connection.id)
            onDisconnect?()
        }
    }

    func addNewServer() {
        resetDraftState()
        selectedID = nil
        log.info("[ConnToSrvr] new draft server created")
    }

    func removeSelected() {
        guard let id = selectedID,
            let server = store.servers.first(where: { $0.id == id })
        else {
            return
        }

        deleteServerAction(server: server)
    }

    func selectFirst() {
        log.debug("[ConnToSrvr] selectFirst invoked, servers=\(store.servers.count)")

        if let first = store.servers.first {
            selectedID = first.id
            applyServerToDraft(first)
            log.info("[ConnToSrvr] selected first server host=\(first.host)")
            return
        }

        resetDraftState()
        log.info("[ConnToSrvr] no saved servers, created empty draft")
    }

    func applyPendingFocusOrSelectFirst() {
        let coord = ConnectToServerCoordinator.shared
        if let pendingID = coord.pendingServerID,
            let server = store.servers.first(where: { $0.id == pendingID })
        {
            selectedID = server.id
            applyServerToDraft(server)
            if let field = coord.pendingFocusField {
                focusedField = mapFieldName(field)
            }
            coord.pendingServerID = nil
            coord.pendingFocusField = nil
            log.info("[ConnToSrvr] focused on pending server=\(server.displayName)")
            return
        }
        if restoreLastSelection() {
            return
        }
        selectFirst()
        restoreLastFocusedField()
    }

    func mapFieldName(_ name: String) -> FormField? {
        switch name {
            case "password": return .password
            case "host": return .host
            case "user": return .user
            case "name": return .name
            case "port": return .port
            case "keyPath": return .keyPath
            default: return nil
        }
    }

    func fieldName(_ field: FormField) -> String {
        switch field {
            case .name: return "name"
            case .host: return "host"
            case .port: return "port"
            case .remotePath: return "remotePath"
            case .user: return "user"
            case .password: return "password"
            case .keyPath: return "keyPath"
        }
    }

    func restoreLastSelection() -> Bool {
        guard let rawID = UserDefaults.standard.string(forKey: Self.selectedServerDefaultsKey),
            let id = UUID(uuidString: rawID),
            let server = store.servers.first(where: { $0.id == id })
        else {
            return false
        }
        selectedID = server.id
        applyServerToDraft(server)
        restoreLastFocusedField()
        log.info("[ConnToSrvr] restored selected server=\(server.displayName)")
        return true
    }

    func restoreLastFocusedField() {
        let rawField = UserDefaults.standard.string(forKey: Self.focusedFieldDefaultsKey)
        let field = rawField.flatMap(mapFieldName) ?? defaultFocusedField()
        Task { @MainActor in
            focusedField = field
        }
    }

    func defaultFocusedField() -> FormField {
        if draft.host.isEmpty { return .host }
        if draft.user.isEmpty { return .user }
        if draft.authType == .privateKey { return .keyPath }
        return .password
    }

    func persistSelectedID(_ id: RemoteServer.ID?) {
        guard let id else {
            UserDefaults.standard.removeObject(forKey: Self.selectedServerDefaultsKey)
            return
        }
        UserDefaults.standard.set(id.uuidString, forKey: Self.selectedServerDefaultsKey)
    }

    func persistFocusedField(_ field: FormField?) {
        guard let field else { return }
        UserDefaults.standard.set(fieldName(field), forKey: Self.focusedFieldDefaultsKey)
    }

    func chooseKeyFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/.ssh")
        panel.title = "Select Private Key"

        if panel.runModal() == .OK, let url = panel.url {
            draft.privateKeyPath = url.path
        }
    }

    @discardableResult
    func applyURLParserIfNeeded(_ input: String, clearName: Bool) -> Bool {
        guard let parsed = RemoteServerURLParser.parse(input) else { return false }
        guard let host = parsed.host, !host.isEmpty else { return false }

        log.debug("[ConnToSrvr] URL-parsed input='\(input)' → host=\(host)")

        draft.host = host

        if let proto = parsed.proto {
            draft.remoteProtocol = proto
            draft.port = parsed.port ?? proto.defaultPort
        } else if let port = parsed.port {
            draft.port = port
        }

        if let user = parsed.user {
            draft.user = user
        }

        if let path = parsed.remotePath {
            draft.remotePath = path
        }

        if clearName {
            draft.name = ""
            nameWasManuallyEdited = false
        } else if !nameWasManuallyEdited {
            draft.name = host
        }

        if let parsedPassword = parsed.password, !parsedPassword.isEmpty {
            password = parsedPassword
            keepPassword = true
        }

        focusedField = draft.user.isEmpty ? .user : .password
        return true
    }

    func saveActionWithFeedback() {
        saveAction()

        do {
            try Self.exportToExternalSFTP(store: store)
            flashSaveIcon(success: true)
            log.info("[ConnToSrvr] saved + exported OK")
        } catch {
            flashSaveIcon(success: false)
            log.error("[ConnToSrvr] export failed: \(error.localizedDescription)")
        }
    }

    func silentExport() {
        do {
            try Self.exportToExternalSFTP(store: store)
        } catch {
            log.error("[ConnToSrvr] silent export failed: \(error.localizedDescription)")
        }
    }
}
