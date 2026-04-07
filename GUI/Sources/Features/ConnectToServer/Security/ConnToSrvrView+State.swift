//
//  ConnToSrvrView+State.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Draft State
extension ConnToSrvrView {

    func applyServerToDraft(_ server: RemoteServer) {
        draft = server
        password = RemoteServerKeychain.loadPassword(for: server)
        let hasSavedPassword = !password.isEmpty
        keepPassword = hasSavedPassword
        log.debug("[ConnToSrvr] applyServerToDraft host=\(server.host) hasSavedPassword=\(hasSavedPassword)")
        nameWasManuallyEdited = !server.name.isEmpty && server.name != server.host
    }

    func resetDraftState() {
        draft = RemoteServer()
        password = ""
        keepPassword = true
        log.debug("[ConnToSrvr] reset draft state")
        nameWasManuallyEdited = false
    }

    func refreshDraftFromStore() {
        guard let fresh = store.servers.first(where: { $0.id == draft.id }) else { return }
        draft = fresh
    }

    func flashSaveIcon(success: Bool) {
        saveFlashIcon = success ? "checkmark.circle.fill" : "xmark.circle.fill"
        saveFlashColor = success ? .green : .red
        showSaveFlash = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            showSaveFlash = false
        }
    }

    func handleHostChanged(_ newValue: String) {
        if applyURLParserIfNeeded(newValue, clearName: false) {
            return
        }

        if !nameWasManuallyEdited || draft.name.isEmpty {
            draft.name = newValue
        }
    }
}
