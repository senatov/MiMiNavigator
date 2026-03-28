// ConnectToServerView.swift
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

// MARK: - ConnectToServerView
struct ConnectToServerView: View {

    var onConnect: ((URL, String) -> Void)?
    var onDisconnect: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var store = RemoteServerStore.shared
    @State private var selectedID: RemoteServer.ID?
    @State private var draft = RemoteServer()
    @State private var password: String = ""
    @State private var keepPassword: Bool = true
    // @Observable singleton — accessed directly, SwiftUI tracks changes automatically
    private var connectionManager: RemoteConnectionManager { .shared }
    @State private var isConnecting: Bool = false
    @State private var sessionLayout = SessionColumnLayout()
    @State private var showPassword: Bool = false
    @State private var connectionError: String = ""
    @State private var showSaveAlert: Bool = false
    @State private var saveAlertIcon: String = "checkmark.circle.fill"
    @State private var saveAlertColor: Color = .green
    @State private var saveAlertTitle: String = ""
    @State private var saveAlertMessage: String = ""
    @State private var nameWasManuallyEdited: Bool = false

    @FocusState private var focusedField: FormField?
    @Namespace private var focusNamespace

    private enum FormField: Hashable {
        case name, host, port, remotePath, user, password, keyPath
    }

    private var dialogBgColor: Color {
        let s = ColorThemeStore.shared
        if !s.hexDialogBackground.isEmpty, let c = Color(hex: s.hexDialogBackground) {
            return c
        }
        return s.activeTheme.dialogBackground
    }

    // MARK: - Body
    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 120, idealWidth: 260, maxWidth: 500)
            contentPane
                .frame(minWidth: 320)
        }
        .focusScope(focusNamespace)
        .frame(minWidth: 660, idealWidth: 760, minHeight: 440, idealHeight: 520)
        .background(dialogBgColor.ignoresSafeArea())
        .glassEffect()
        .onAppear { selectFirst() }
        .onKeyPress(.escape) {
            onDismiss?()
            return .handled
        }
        .overlay { saveAlertOverlay }
    }

    // MARK: - Save Alert Overlay
    @ViewBuilder
    private var saveAlertOverlay: some View {
        if showSaveAlert {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showSaveAlert = false }
                HIGAlertDialog(
                    icon: saveAlertIcon,
                    iconColor: saveAlertColor,
                    title: saveAlertTitle,
                    message: saveAlertMessage,
                    onDismiss: { showSaveAlert = false }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            .animation(.easeOut(duration: 0.15), value: showSaveAlert)
        }
    }

    // MARK: - Sidebar Search Header
    private var sidebarSearchHeader: some View {
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
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Sidebar Footer Toolbar
    private var sidebarFooterToolbar: some View {
        HStack(spacing: 2) {
            Button {
                addNewServer()
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.plain)
            .help("Add new server")

            Button {
                removeSelected()
            } label: {
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
        .overlay(alignment: .top) { Divider() }
        .glassEffect()
    }

    // MARK: - Sidebar (ForkLift / Settings style)
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Search placeholder (matches Settings)
            sidebarSearchHeader

            // Server list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(store.servers) { server in
                        sidebarServerRow(server)
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: selectedID) { _, newID in
                connectionError = ""
                ConnectErrorPopupController.shared.hide()
                guard let id = newID,
                      let server = store.servers.first(where: { $0.id == id })
                else { return }
                applyServerToDraft(server)
                log.debug("\(#function) switched to server '\(server.displayName)'")
            }

            Spacer(minLength: 0)

            // Bottom +/− toolbar (matches Settings ellipsis footer)
            sidebarFooterToolbar
        }
        .background(DialogColors.base.opacity(0.72))
        .glassEffect()
    }

    // MARK: - Sidebar Server Row (matches Settings sidebarRow)
    private func sidebarServerRow(_ server: RemoteServer) -> some View {
        let isSelected = selectedID == server.id
        // Status color: green=connected, red=error, grey=idle — same logic as ConnectionStatusLamp
        let connected = connectionManager.isConnected(to: server)
        let statusColor = sidebarStatusColor(for: server, isSelected: isSelected, connected: connected)
        return HStack(spacing: 8) {
            Image(systemName: Self.iconForProtocol(server.remoteProtocol))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: isSelected ? .light : .regular))
                    .foregroundStyle(isSelected ? .white : Color.primary)
                    .lineLimit(1)
                Text(server.sessionSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedID = server.id
            }
        }
        .contextMenu {
            Button("Connect") {
                connectServerAction(server: server)
            }

            Button("Disconnect") {
                disconnectServerAction(server: server)
            }
            .disabled(!connectionManager.isConnected(to: server) || isConnecting)

            Divider()

            Button("Delete", role: .destructive) {
                deleteServerAction(server: server)
            }
        }
        .padding(.horizontal, 6)
        .glassEffect()
    }

    // MARK: - Sidebar Row Status Color
    private func sidebarStatusColor(for server: RemoteServer, isSelected: Bool, connected: Bool) -> Color {
        if isSelected { return .white }
        if connected { return .green }

        switch server.lastResult {
            case .authFailed, .timeout, .refused, .error:
                return Color(nsColor: .systemRed)
            default:
                return Color(nsColor: .systemGray).opacity(0.7)
        }
    }

    // MARK: - Content Pane (matches Settings contentPane)
    private var contentPane: some View {
        ZStack {
            dialogBgColor.opacity(0.82)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitleBar
                    Divider().padding(.horizontal, 24).padding(.bottom, 16)
                    connectionFormContent
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .glassEffect()
    }

    // MARK: - Section Title Bar
    private var sectionTitleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: Self.iconForProtocol(draft.remoteProtocol))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DialogColors.accent)
            Text(draft.remoteProtocol.rawValue)
                .font(.system(size: 17, weight: .light))

            // ── Status lamp ──────────────────────────────────────
            ConnectionStatusLamp(server: draft, manager: connectionManager)

            Spacer()

            if !connectionError.isEmpty {
                GeometryReader { geo in
                    Button {
                        let frame = geo.frame(in: .global)
                        ConnectErrorPopupController.shared.show(
                            server: draft, anchorFrame: frame)
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
            if isConnecting {
                ProgressView().controlSize(.small)
            }
        }
        .glassEffect()
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Connection Form (SettingsGroupBox / SettingsRow layout)
    private var connectionFormContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Server identity group
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(
                        label: "Name:", help: "Bookmark name for this server. Paste a URL here to auto-fill all fields.",
                        labelWidth: 120
                    ) {
                        TextField("or paste URL: sftp://user@host:port/path", text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                            .glassEffect()
                            .focused($focusedField, equals: .name)
                            .onChange(of: draft.name) { _, newValue in
                                if applyURLParserIfNeeded(newValue, clearName: true) { return }
                                if !newValue.isEmpty { nameWasManuallyEdited = true }
                            }
                    }
                    Divider()
                    SettingsRow(label: "Protocol:", help: "Connection protocol", labelWidth: 120) {
                        Picker("", selection: $draft.remoteProtocol) {
                            ForEach(RemoteProtocol.allCases) { proto in
                                Text(proto.rawValue).tag(proto)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .glassEffect()
                        .onChange(of: draft.remoteProtocol) { _, newProto in
                            if draft.port == 0 || RemoteProtocol.allCases.map(\.defaultPort).contains(draft.port) {
                                draft.port = newProto.defaultPort
                            }
                        }
                    }
                    Divider()
                    SettingsRow(label: "Host:", help: "Hostname, IP, or paste full URL/connection string", labelWidth: 120) {
                        TextField("host  or  user@host:port  or  ftp://host/path", text: $draft.host)
                            .textFieldStyle(.roundedBorder)
                            .glassEffect()
                            .focused($focusedField, equals: .host)
                            .onChange(of: draft.host) { _, newValue in
                                if applyURLParserIfNeeded(newValue, clearName: false) { return }
                                if !nameWasManuallyEdited || draft.name.isEmpty {
                                    draft.name = newValue
                                }
                            }
                            .onSubmit { draft.host = Self.sanitizeHost(draft.host) }
                    }
                    Divider()
                    SettingsRow(label: "Port:", help: "Server port number", labelWidth: 120) {
                        TextField("", value: $draft.port, formatter: Self.portFormatter)
                            .textFieldStyle(.roundedBorder)
                            .glassEffect()
                            .focused($focusedField, equals: .port)
                            .frame(width: 80)
                    }
                    Divider()
                    SettingsRow(label: "Remote Path:", help: "Initial directory on server", labelWidth: 120) {
                        TextField("", text: $draft.remotePath)
                            .textFieldStyle(.roundedBorder)
                            .glassEffect()
                            .focused($focusedField, equals: .remotePath)
                    }
                }
            }
            .glassEffect()

            // Authentication group
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "User:", help: "Login username", labelWidth: 120) {
                        TextField("", text: $draft.user)
                            .textFieldStyle(.roundedBorder)
                            .glassEffect()
                            .focused($focusedField, equals: .user)
                    }
                    Divider()
                    SettingsRow(label: "Password:", help: "Login password", labelWidth: 120) {
                        HStack(spacing: 6) {
                            ZStack {
                                if showPassword {
                                    TextField("", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                        .glassEffect()
                                        .focused($focusedField, equals: .password)
                                } else {
                                    SecureField("", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                        .glassEffect()
                                        .focused($focusedField, equals: .password)
                                }
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                            }
                            .buttonStyle(.plain)
                            .glassEffect()
                            .help(showPassword ? "Hide password" : "Show password")
                            Toggle("Keep", isOn: $keepPassword)
                                .toggleStyle(.checkbox)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Authenticate:", help: "Authentication method", labelWidth: 120) {
                        Picker("", selection: $draft.authType) {
                            ForEach(RemoteAuthType.allCases) { auth in
                                Text(auth.rawValue).tag(auth)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .horizontalRadioGroupLayout()
                        .labelsHidden()
                        .glassEffect()
                    }
                    if draft.authType == .privateKey {
                        Divider()
                        SettingsRow(label: "Key Path:", help: "Path to SSH private key", labelWidth: 120) {
                            HStack(spacing: 6) {
                                TextField("", text: $draft.privateKeyPath)
                                    .textFieldStyle(.roundedBorder)
                                    .glassEffect()
                                    .focused($focusedField, equals: .keyPath)
                                Button("Choose…") { chooseKeyFile() }
                                    .controlSize(.small)
                                    .glassEffect()
                            }
                        }
                    }
                    Divider()
                    SettingsRow(label: "Startup:", help: "Automatically connect when MiMiNavigator starts", labelWidth: 120) {
                        Toggle("Connect when app starts", isOn: $draft.connectOnStart)
                            .toggleStyle(.checkbox)
                    }
                }
            }
            .glassEffect()

            // Action buttons
            HStack(spacing: 12) {
                Spacer()
                Button("Disconnect") { disconnectAction() }
                    .disabled(!canDisconnectCurrentDraft)
                    .buttonStyle(AnimatedDialogButtonStyle(role: .destructive))
                Button("Save") { saveActionWithFeedback() }
                    .disabled(draft.host.isEmpty)
                    .buttonStyle(AnimatedDialogButtonStyle())
                Button("Connect") { connectAction() }
                    .disabled(draft.host.isEmpty || isConnecting)
                    .buttonStyle(AnimatedDialogButtonStyle(role: .confirm))
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .glassEffect()
        }
    }

    // MARK: - Draft State Helpers
    private func applyServerToDraft(_ server: RemoteServer) {
        draft = server
        password = RemoteServerKeychain.loadPassword(for: server)
        keepPassword = !password.isEmpty
        nameWasManuallyEdited = !server.name.isEmpty && server.name != server.host
    }

    private func resetDraftState() {
        draft = RemoteServer()
        password = ""
        keepPassword = true
        nameWasManuallyEdited = false
    }

    private func refreshDraftFromStore() {
        guard let fresh = store.servers.first(where: { $0.id == draft.id }) else { return }
        draft = fresh
    }

    private func presentSaveFeedback(title: String, message: String, icon: String, color: Color) {
        saveAlertTitle = title
        saveAlertMessage = message
        saveAlertIcon = icon
        saveAlertColor = color
        showSaveAlert = true
    }

    // MARK: - Actions

    // MARK: - Disconnect availability
    private var currentDraftConnectionAvailable: Bool {
        connectionManager.isConnected(to: draft)
    }

    private var canDisconnectCurrentDraft: Bool {
        currentDraftConnectionAvailable && !isConnecting
    }

    // MARK: - connectAction
    private func connectAction() {
        saveAction()
        connectionError = ""
        guard let url = draft.connectionURL else {
            connectionError = "Invalid URL"
            log.warning("[ConnectToServer] invalid URL for '\(draft.host)'")
            return
        }
        let scheme = url.scheme ?? ""
        log.debug(
            "[ConnectToServer] attempt host=\(draft.host) port=\(draft.port) proto=\(draft.remoteProtocol.rawValue) auth=\(draft.authType.rawValue) keepPassword=\(keepPassword)"
        )
        if let existing = connectionManager.connection(for: draft) {
            log.info("[ConnectToServer] reusing existing connection to \(draft.host)")
            connectionManager.setActive(id: existing.id)
            onConnect?(url, password)
            return
        }
        isConnecting = true
        log.info("[ConnectToServer] connecting to \(url)")

        if scheme == "smb" || scheme == "afp" {
            onConnect?(url, password)
            isConnecting = false
            return
        }

        Task {
            await finishRemoteConnect(url: url)
        }
    }

    private func finishRemoteConnect(url: URL) async {
        await connectionManager.connect(to: draft, password: password)
        log.debug("[ConnectToServer] connect() finished, isConnected=\(connectionManager.isConnected)")

        if connectionManager.isConnected(to: draft) {
            log.info("[ConnectToServer] connection SUCCESS host=\(draft.host)")
            connectionError = ""
            onConnect?(url, password)
            isConnecting = false
            return
        }

        refreshDraftFromStore()
        let reason = draft.lastResult.rawValue
        log.warning("[ConnectToServer] connect failed host=\(draft.host)")
        log.warning("[ConnectToServer] result=\(reason)")
        log.warning("[ConnectToServer] detail=\(draft.lastErrorDetail ?? "—")")
        connectionError = reason
        isConnecting = false
    }

    // MARK: - saveAction
    private func saveAction() {
        log.debug("[ConnectToServer] saveAction for host=\(draft.host) id=\(draft.id)")
        if draft.name.isEmpty { draft.name = draft.host }
        if keepPassword && !password.isEmpty {
            RemoteServerKeychain.savePassword(password, for: draft)
        } else if !keepPassword {
            RemoteServerKeychain.deletePassword(for: draft)
        }
        if store.servers.contains(where: { $0.id == draft.id }) {
            store.update(draft)
        } else {
            store.add(draft)
        }
        log.info("[ConnectToServer] bookmark saved host=\(draft.host)")
        selectedID = draft.id
    }

    // MARK: - disconnectAction
    private func disconnectAction() {
        guard canDisconnectCurrentDraft else {
            log.debug("[ConnectToServer] disconnect ignored")
            log.debug("[ConnectToServer] current draft is not actively connected")
            return
        }

        guard let conn = connectionManager.connection(for: draft) else {
            log.debug("[ConnectToServer] disconnect ignored")
            log.debug("[ConnectToServer] no connection object for current draft")
            return
        }

        log.info("[ConnectToServer] disconnecting from \(draft.host)")
        Task {
            await connectionManager.disconnect(id: conn.id)
            onDisconnect?()
        }
    }

    // MARK: - deleteServerAction
    private func deleteServerAction(server: RemoteServer) {
        if let conn = connectionManager.connection(for: server) {
            Task { await connectionManager.disconnect(id: conn.id) }
        }
        RemoteServerKeychain.deletePassword(for: server)
        store.remove(server)
        onDisconnect?()
        selectFirst()
        log.info("[ConnectToServer] deleted server \(server.displayName)")
    }

    // MARK: - connectServerAction
    private func connectServerAction(server: RemoteServer) {
        applyServerToDraft(server)
        selectedID = server.id
        connectAction()
    }

    // MARK: - disconnectServerAction
    private func disconnectServerAction(server: RemoteServer) {
        guard connectionManager.isConnected(to: server) else {
            log.debug("[ConnectToServer] server disconnect ignored")
            log.debug("[ConnectToServer] server is not connected: \(server.displayName)")
            return
        }

        guard let conn = connectionManager.connection(for: server) else {
            log.debug("[ConnectToServer] server disconnect ignored")
            log.debug("[ConnectToServer] no connection object for server: \(server.displayName)")
            return
        }

        Task {
            await connectionManager.disconnect(id: conn.id)
            onDisconnect?()
        }
    }

    // MARK: - addNewServer
    private func addNewServer() {
        resetDraftState()
        selectedID = nil
        log.info("[ConnectToServer] new draft server created")
    }

    // MARK: - removeSelected
    private func removeSelected() {
        guard let id = selectedID,
            let server = store.servers.first(where: { $0.id == id })
        else { return }
        store.remove(server)
        selectFirst()
    }

    // MARK: - selectFirst
    private func selectFirst() {
        log.debug("[ConnectToServer] selectFirst invoked, servers=\(store.servers.count)")
        if let first = store.servers.first {
            selectedID = first.id
            applyServerToDraft(first)
            log.info("[ConnectToServer] selected first server host=\(first.host)")
            return
        }

        resetDraftState()
        log.info("[ConnectToServer] no saved servers, created empty draft")
    }

    // MARK: - chooseKeyFile
    private func chooseKeyFile() {
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

    // MARK: - applyURLParserIfNeeded
    /// Tries to parse `input` as a URL/connection string.
    /// If successful, fills all draft fields and returns true (caller should skip normal onChange logic).
    /// `clearName`: if true, replaces draft.name with host (input came from Name field).
    @discardableResult
    private func applyURLParserIfNeeded(_ input: String, clearName: Bool) -> Bool {
        guard let parsed = RemoteServerURLParser.parse(input) else { return false }
        // Need at least a host to be useful
        guard let host = parsed.host, !host.isEmpty else { return false }

        log.debug("[ConnectToServer] URL-parsed input='\(input)' → host=\(host)")

        // Apply parsed fields — only overwrite non-empty results
        draft.host = host
        if let proto = parsed.proto {
            draft.remoteProtocol = proto
            // Auto-set port only if it was explicitly in the URL, or reset to default
            draft.port = parsed.port ?? proto.defaultPort
        } else if let port = parsed.port {
            draft.port = port
        }
        if let user = parsed.user { draft.user = user }
        if let path = parsed.remotePath { draft.remotePath = path }
        if clearName {
            // Input was pasted into Name field — move host to Host, clear Name for user label
            draft.name = ""
            nameWasManuallyEdited = false
        } else {
            // Input was pasted into Host — use host as name if not manually set
            if !nameWasManuallyEdited { draft.name = host }
        }

        // Surface parsed password to the password field (not stored in model)
        if let pwd = parsed.password, !pwd.isEmpty {
            password = pwd
            keepPassword = true
        }

        // Move focus to next logical field
        focusedField = draft.user.isEmpty ? .user : .password
        return true
    }

    // MARK: - saveActionWithFeedback
    private func saveActionWithFeedback() {
        saveAction()
        do {
            let filePath = try Self.exportToExternalSFTP(store: store)
            presentSaveFeedback(
                title: "Saved",
                message: "Configuration written to\n\(filePath)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            log.info("[ConnectToServer] exported to \(filePath)")
        } catch {
            presentSaveFeedback(
                title: "Save Failed",
                message: Self.describeError(error),
                icon: "xmark.circle.fill",
                color: .red
            )
            log.error("[ConnectToServer] export failed: \(error.localizedDescription)")
        }
    }
}
