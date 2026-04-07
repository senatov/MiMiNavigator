//
//  RemoteSrKeyChain+Fail.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation
import LocalAuthentication
import Security


// MARK: - Load Failure Handling

extension RemoteServerKeychain {

    static func handleLoadFailure(_ status: OSStatus, for server: RemoteServer) {
        if status == errSecItemNotFound {
            log.info("[Keychain] no saved password for \(endpointDescription(for: server))")
            removeCachedPassword(for: server)
            updatePasswordIndex(for: server, hasPassword: false, lastError: nil)
            return
        }

        if status == errSecInteractionNotAllowed {
            log.warning(
                "[Keychain] load skipped interactive auth for \(endpointDescription(for: server)) status=\(status) message='\(statusDescription(status))'"
            )
            updatePasswordIndex(
                for: server,
                hasPassword: false,
                lastError: "interactive auth not allowed: \(statusDescription(status))"
            )
            return
        }

        logKeychainFailure("load", status: status, server: server)
        updatePasswordIndex(for: server, hasPassword: false, lastError: "load failed: \(statusDescription(status))")
    }
}

