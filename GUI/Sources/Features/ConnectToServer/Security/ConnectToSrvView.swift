// ConnToSrvrView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: "Connect to Server" dialog — SFTP/FTP/SMB/AFP bookmark manager.
//   Aesthetic unified with SettingsWindowView: HSplitView sidebar + content pane,
//   DialogColors background, SettingsGroupBox/SettingsRow form layout, sectionTitleBar.
//   Left sidebar: ForkLift-style server list with +/− footer.
//   Right pane: grouped connection form (SettingsGroupBox / SettingsRow).

import AppKit
import SwiftUI

// MARK: - ConnToSrvrView

struct ConnToSrvrView: View {

    var onConnect: ((URL, String) -> Void)?
    var onDisconnect: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State var store = RemoteServerStore.shared
    @State var selectedID: RemoteServer.ID?
    @State var draft = RemoteServer()
    @State var password: String = ""
    @State var keepPassword: Bool = true
    @State var isConnecting: Bool = false
    @State var sessionLayout = SessionColumnLayout()
    @State var showPassword: Bool = false
    @State var connectionError: String = ""
    @State var showSaveFlash: Bool = false
    @State var saveFlashIcon: String = "checkmark.circle.fill"
    @State var saveFlashColor: Color = .green
    @State var nameWasManuallyEdited: Bool = false
    @State var sidebarWidth: CGFloat = Layout.idealSidebarWidth
    @State var lastCommittedSidebarWidth: CGFloat = Layout.idealSidebarWidth

    @FocusState var focusedField: FormField?
    @Namespace var focusNamespace
    @State var isDividerHovered: Bool = false
    @State var isDividerDragging: Bool = false
    @State var isDividerCursorActive: Bool = false

    enum FormField: Hashable {
        case name, host, port, remotePath, user, password, keyPath
    }

    private static let dividerHoverTintOpacity: Double = 0.10
    private static let dividerIdleTintOpacity: Double = 0.04
    private static let dividerBorderOpacity: Double = 0.18

    // MARK: - Derived State

    var connectionManager: RemoteConnectionManager { .shared }

    var dialogBgColor: Color {
        let store = ColorThemeStore.shared
        if !store.hexDialogBackground.isEmpty,
            let color = Color(hex: store.hexDialogBackground)
        {
            return color
        }
        return store.activeTheme.dialogBackground
    }

    var clampedSidebarWidth: CGFloat {
        min(max(sidebarWidth, Layout.minSidebarWidth), Layout.maxSidebarWidth)
    }

    var dividerActive: Bool {
        isDividerHovered || isDividerDragging
    }

    var dividerTintOpacity: Double {
        dividerActive ? Self.dividerHoverTintOpacity : Self.dividerIdleTintOpacity
    }

    var dividerBorderStrokeOpacity: Double {
        dividerActive ? Self.dividerBorderOpacity : Self.dividerBorderOpacity * 0.7
    }

    var currentDraftConnectionAvailable: Bool {
        connectionManager.isConnected(to: draft)
    }

    var canDisconnectCurrentDraft: Bool {
        currentDraftConnectionAvailable && !isConnecting
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                sidebar
                    .frame(width: resolvedSidebarWidth(totalWidth: geometry.size.width))

                splitDivider(totalWidth: geometry.size.width)

                contentPane
                    .frame(minWidth: Layout.minContentWidth, maxWidth: .infinity)
            }
            .focusScope(focusNamespace)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: Layout.windowMinWidth,
            idealWidth: Layout.windowIdealWidth,
            minHeight: Layout.windowMinHeight,
            idealHeight: Layout.windowIdealHeight
        )
        .background(dialogBgColor.ignoresSafeArea())
        .glassEffect()
        .onAppear(perform: handleAppear)
        .onDisappear(perform: releaseDividerCursorIfNeeded)
        .onExitCommand {
            onDismiss?()
        }
    }
}
