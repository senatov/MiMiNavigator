//
//  ConnToSrvrView+Flow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Connection Flow

extension ConnToSrvrView {

    func logConnectionAttempt(url: URL) {
        log.debug(
            "[ConnToSrvr] attempt host=\(draft.host) port=\(draft.port) proto=\(draft.remoteProtocol.rawValue) auth=\(draft.authType.rawValue) keepPassword=\(keepPassword)"
        )
        log.info("[ConnToSrvr] connecting to \(url)")
    }

    func reuseExistingConnectionIfPossible(url: URL) -> Bool {
        guard let existing = connectionManager.connection(for: draft) else {
            return false
        }

        log.info("[ConnToSrvr] reusing existing connection to \(draft.host)")
        connectionManager.setActive(id: existing.id)
        onConnect?(url, password)
        return true
    }

    func startConnection(for url: URL) {
        isConnecting = true

        if isManagedSMBProtocol(url) {
            Task {
                await finishRemoteConnect(url: url)
            }
            return
        }

        if isSystemMountProtocol(url) {
            onConnect?(url, password)
            isConnecting = false
            return
        }

        Task {
            await finishRemoteConnect(url: url)
        }
    }

    func isManagedSMBProtocol(_ url: URL) -> Bool {
        (url.scheme ?? "") == "smb"
    }

    func isSystemMountProtocol(_ url: URL) -> Bool {
        let scheme = url.scheme ?? ""
        return scheme == "afp"
    }

    func handleConnectionSuccess(url: URL) {
        log.info("[ConnToSrvr] connection SUCCESS host=\(draft.host)")
        connectionError = ""
        onConnect?(url, password)
        isConnecting = false
    }

    func handleConnectionFailure() {
        refreshDraftFromStore()
        let result = draft.lastResult
        let reason = result.rawValue
        log.warning("[ConnToSrvr] connect failed host=\(draft.host)")
        log.warning("[ConnToSrvr] result=\(reason)")
        log.warning("[ConnToSrvr] detail=\(draft.lastErrorDetail ?? "—")")
        connectionError = connectionErrorTitle(result: result, detail: draft.lastErrorDetail)
        isConnecting = false
        focusFieldForError(result)
    }

    func connectionErrorTitle(result: ConnectionResult, detail: String?) -> String {
        guard draft.remoteProtocol == .smb,
            let detail,
            detail.localizedCaseInsensitiveContains("share")
        else {
            return result.rawValue
        }
        return "SMB Share Required"
    }

    func persistPasswordIfNeeded() {
        if keepPassword {
            if password.isEmpty {
                log.info("[ConnToSrvr] keepPassword enabled but password is empty for \(draft.displayName)")
                return
            }

            RemoteServerKeychain.savePassword(password, for: draft)
            return
        }

        RemoteServerKeychain.deletePassword(for: draft)
        log.debug("[ConnToSrvr] keepPassword disabled, removed stored password for \(draft.displayName)")
    }

    func persistDraftBookmark() {
        if store.servers.contains(where: { $0.id == draft.id }) {
            store.update(draft)
        } else {
            store.add(draft)
        }
    }
}

// MARK: - Split Divider

extension ConnToSrvrView {

    func activateDividerCursorIfNeeded() {
        guard !isDividerCursorActive else { return }
        NSCursor.resizeLeftRight.push()
        isDividerCursorActive = true
    }

    func releaseDividerCursorIfNeeded() {
        guard isDividerCursorActive else { return }
        NSCursor.pop()
        isDividerCursorActive = false
    }

    func resolvedSidebarWidth(totalWidth: CGFloat) -> CGFloat {
        min(max(clampedSidebarWidth, Layout.minSidebarWidth), maxAllowedSidebarWidth(totalWidth: totalWidth))
    }

    func maxAllowedSidebarWidth(totalWidth: CGFloat) -> CGFloat {
        max(
            Layout.minSidebarWidth,
            min(Layout.maxSidebarWidth, totalWidth - Layout.minContentWidth - Layout.dividerVisualWidth)
        )
    }

    func splitDivider(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: Layout.dividerHitWidth)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(dividerTintOpacity))
                    .frame(width: Layout.dividerCapsuleWidth, height: Layout.dividerCapsuleHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.white.opacity(dividerBorderStrokeOpacity), lineWidth: 0.8)
                    }
                    .glassEffect()
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                handleDividerHover(hovering)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDividerDragChanged(value, totalWidth: totalWidth)
                    }
                    .onEnded { _ in
                        handleDividerDragEnded(totalWidth: totalWidth)
                    }
            )
            .onTapGesture(count: 2, perform: resetSidebarWidthToDefault)
            .help("Drag to resize sidebar")
    }

    func handleDividerHover(_ hovering: Bool) {
        isDividerHovered = hovering
        if hovering {
            activateDividerCursorIfNeeded()
            return
        }

        if !isDividerDragging {
            releaseDividerCursorIfNeeded()
        }
    }

    func handleDividerDragChanged(_ value: DragGesture.Value, totalWidth: CGFloat) {
        isDividerDragging = true
        activateDividerCursorIfNeeded()

        sidebarWidth = min(
            max(lastCommittedSidebarWidth + value.translation.width, Layout.minSidebarWidth),
            maxAllowedSidebarWidth(totalWidth: totalWidth)
        )
    }

    func handleDividerDragEnded(totalWidth: CGFloat) {
        isDividerDragging = false
        sidebarWidth = resolvedSidebarWidth(totalWidth: totalWidth)
        lastCommittedSidebarWidth = sidebarWidth
        persistSidebarWidth(sidebarWidth)

        if !isDividerHovered {
            releaseDividerCursorIfNeeded()
        }
    }

    func resetSidebarWidthToDefault() {
        sidebarWidth = Layout.idealSidebarWidth
        lastCommittedSidebarWidth = Layout.idealSidebarWidth
        persistSidebarWidth(Layout.idealSidebarWidth)
    }

    func restoreSidebarWidth() {
        let storedWidth = UserDefaults.standard.double(forKey: Layout.sidebarWidthDefaultsKey)
        guard storedWidth > 0 else {
            sidebarWidth = Layout.idealSidebarWidth
            lastCommittedSidebarWidth = Layout.idealSidebarWidth
            return
        }

        let restoredWidth = CGFloat(storedWidth)
        sidebarWidth = restoredWidth
        lastCommittedSidebarWidth = restoredWidth
    }

    func persistSidebarWidth(_ width: CGFloat) {
        UserDefaults.standard.set(width, forKey: Layout.sidebarWidthDefaultsKey)
    }
}
