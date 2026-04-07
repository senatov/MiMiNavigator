//
//  ConnToSrvrView+Side.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Layout
extension ConnToSrvrView {

    var sidebar: some View {
        VStack(spacing: 0) {
            sidebarSearchHeader

            ScrollView {

                LazyVStack(spacing: 1) {
                    ForEach(store.servers) { server in
                        sidebarServerRow(server)
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: selectedID) { _, newID in
                handleSelectionChange(newID)
            }

            Spacer(minLength: 0)
            sidebarFooterToolbar
        }
        .background(DialogColors.base.opacity(0.72))
        .overlay(alignment: .trailing) {
            Divider()
                .opacity(0.22)
        }
        .glassEffect()
    }

    var contentPane: some View {
        ZStack {
            dialogBgColor.opacity(0.82)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitleBar
                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    connectionFormContent
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect()
    }

    var sidebarSearchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            Text("Search")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        .glassEffect()
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    var sidebarFooterToolbar: some View {
        HStack(spacing: 2) {
            Button(action: addNewServer) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.plain)
            .help("Add new server")

            Button(action: removeSelected) {
                Image(systemName: "minus")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.plain)
            .help("Remove selected server")
            .disabled(selectedID == nil)

            Spacer()
        }
        .padding(10)
        .overlay(alignment: .top) {
            Divider()
        }
        .glassEffect()
    }

    var sectionTitleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: Self.iconForProtocol(draft.remoteProtocol))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DialogColors.accent)

            Text(draft.remoteProtocol.rawValue)
                .font(.system(size: 17, weight: .light))

            ConnectionStatusLamp(server: draft, manager: connectionManager)

            Spacer()

            if !connectionError.isEmpty {
                connectionErrorButton
            }

            if isConnecting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .glassEffect()
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    var connectionErrorButton: some View {
        GeometryReader { geo in
            Button {
                let frame = geo.frame(in: .global)
                ConnectErrorPopupController.shared.show(server: draft, anchorFrame: frame)
            } label: {
                Label(connectionError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemOrange))
                    .lineLimit(1)
            }
            .glassEffect()
            .help("Tap for full diagnostics")
        }
        .frame(height: 18)
    }

    var connectionFormContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            identityGroup
            authenticationGroup
            actionButtonsRow
        }
    }

    var identityGroup: some View {
        SettingsGroupBox {
            VStack(spacing: 0) {
                nameRow
                Divider()
                protocolRow
                Divider()
                hostRow
                Divider()
                portRow
                Divider()
                remotePathRow
            }
        }
        .glassEffect()
    }

    var authenticationGroup: some View {
        SettingsGroupBox {
            VStack(spacing: 0) {
                userRow
                Divider()
                passwordRow
                Divider()
                authenticateRow

                if draft.authType == .privateKey {
                    Divider()
                    keyPathRow
                }

                Divider()
                startupRow
            }
        }
        .glassEffect()
    }

    var actionButtonsRow: some View {
        HStack(spacing: 12) {
            Spacer()

            Button("Disconnect", action: disconnectAction)
                .disabled(!canDisconnectCurrentDraft)
                .buttonStyle(AnimatedDialogButtonStyle(role: .destructive))

            saveButton
                .disabled(draft.host.isEmpty)

            Button("Connect", action: connectAction)
                .disabled(draft.host.isEmpty || isConnecting)
                .buttonStyle(AnimatedDialogButtonStyle(role: .confirm))
                .keyboardShortcut(.return, modifiers: .command)
        }
        .glassEffect()
    }

    var saveButton: some View {
        Button(action: saveActionWithFeedback) {
            ZStack {
                Text("Save")
                if showSaveFlash {
                    Image(systemName: saveFlashIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(saveFlashColor)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(AnimatedDialogButtonStyle())
        .animation(.easeOut(duration: 0.2), value: showSaveFlash)
    }
}
