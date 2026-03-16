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
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
            contentPane
                .frame(minWidth: 360)
        }
        .frame(minWidth: 660, idealWidth: 760, minHeight: 440, idealHeight: 520)
        .background(dialogBgColor.ignoresSafeArea())
        .onAppear { selectFirst() }
        .onKeyPress(.escape) { onDismiss?(); return .handled }
        .overlay {
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
    }

    // MARK: - Sidebar (ForkLift / Settings style)
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Search placeholder (matches Settings)
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
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

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
                if let id = newID, let server = store.servers.first(where: { $0.id == id }) {
                    draft = server
                    password = RemoteServerKeychain.loadPassword(for: server)
                    keepPassword = !password.isEmpty
                    nameWasManuallyEdited = !server.name.isEmpty && server.name != server.host
                }
            }

            Spacer(minLength: 0)

            // Bottom +/− toolbar (matches Settings ellipsis footer)
            HStack(spacing: 2) {
                Button { addNewServer() } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.plain).help("Add new server")
                Button { removeSelected() } label: {
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.plain).help("Remove selected server")
                .disabled(selectedID == nil)
                Spacer()
            }
            .padding(10)
            .overlay(alignment: .top) { Divider() }
        }
        .background(DialogColors.base.opacity(0.96))
    }

    // MARK: - Sidebar Server Row (matches Settings sidebarRow)
    private func sidebarServerRow(_ server: RemoteServer) -> some View {
        let isSelected = selectedID == server.id
        return HStack(spacing: 8) {
            Image(systemName: iconForProtocol(server.remoteProtocol))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : colorForProtocol(server.remoteProtocol))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color.primary)
                    .lineLimit(1)
                Text(server.sessionSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            Spacer()
            if RemoteConnectionManager.shared.connection(for: server) != nil {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { selectedID = server.id } }
        .contextMenu {
            Button("Connect") { connectServerAction(server: server) }
            Button("Disconnect") { disconnectServerAction(server: server) }
                .disabled(RemoteConnectionManager.shared.connection(for: server) == nil)
            Divider()
            Button("Delete", role: .destructive) { deleteServerAction(server: server) }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Content Pane (matches Settings contentPane)
    private var contentPane: some View {
        ZStack {
            dialogBgColor
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
    }

    // MARK: - Section Title Bar (matches Settings)
    private var sectionTitleBar: some View {
        HStack {
            Image(systemName: iconForProtocol(draft.remoteProtocol))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DialogColors.accent)
            Text(draft.remoteProtocol.rawValue)
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            if !connectionError.isEmpty {
                Text(connectionError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            if isConnecting {
                ProgressView()
                    .controlSize(.small)
            }
        }
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
                    SettingsRow(label: "Name:", help: "Bookmark name for this server") {
                        TextField("", text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: draft.name) { _, newValue in
                                if !newValue.isEmpty { nameWasManuallyEdited = true }
                            }
                    }
                    Divider()
                    SettingsRow(label: "Protocol:", help: "Connection protocol") {
                        Picker("", selection: $draft.remoteProtocol) {
                            ForEach(RemoteProtocol.allCases) { proto in
                                Text(proto.rawValue).tag(proto)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: draft.remoteProtocol) { _, newProto in
                            if draft.port == 0 || RemoteProtocol.allCases.map(\.defaultPort).contains(draft.port) {
                                draft.port = newProto.defaultPort
                            }
                        }
                    }
                    Divider()
                    SettingsRow(label: "Host:", help: "Server hostname or IP address") {
                        TextField("", text: $draft.host)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: draft.host) { _, newValue in
                                if !nameWasManuallyEdited || draft.name.isEmpty {
                                    draft.name = newValue
                                }
                            }
                            .onSubmit { draft.host = Self.sanitizeHost(draft.host) }
                    }
                    Divider()
                    SettingsRow(label: "Port:", help: "Server port number") {
                        TextField("", value: $draft.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    Divider()
                    SettingsRow(label: "Remote Path:", help: "Initial directory on server") {
                        TextField("", text: $draft.remotePath)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            // Authentication group
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "User:", help: "Login username") {
                        TextField("", text: $draft.user)
                            .textFieldStyle(.roundedBorder)
                    }
                    Divider()
                    SettingsRow(label: "Password:", help: "Login password") {
                        HStack(spacing: 6) {
                            ZStack {
                                if showPassword {
                                    TextField("", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("", text: $password)
                                        .textFieldStyle(.roundedBorder)
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
                            .help(showPassword ? "Hide password" : "Show password")
                            Toggle("Keep", isOn: $keepPassword)
                                .toggleStyle(.checkbox)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Authenticate:", help: "Authentication method") {
                        Picker("", selection: $draft.authType) {
                            ForEach(RemoteAuthType.allCases) { auth in
                                Text(auth.rawValue).tag(auth)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .horizontalRadioGroupLayout()
                        .labelsHidden()
                    }
                    if draft.authType == .privateKey {
                        Divider()
                        SettingsRow(label: "Key Path:", help: "Path to SSH private key") {
                            HStack(spacing: 6) {
                                TextField("", text: $draft.privateKeyPath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Choose…") { chooseKeyFile() }
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }

            // Options group
            SettingsGroupBox {
                SettingsRow(label: "Startup:", help: "Automatically connect when MiMiNavigator starts") {
                    Toggle("Connect when app starts", isOn: $draft.connectOnStart)
                        .toggleStyle(.checkbox)
                }
            }

            // Action buttons (matches Settings bottom style)
            HStack(spacing: 12) {
                Spacer()
                Button("Disconnect") { disconnectAction() }
                    .disabled(!isDraftConnected)
                Button("Save") { saveActionWithFeedback() }
                    .disabled(draft.host.isEmpty)
                Button("Connect") { connectAction() }
                    .buttonStyle(ThemedButtonStyle())
                    .disabled(draft.host.isEmpty || isConnecting)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    // MARK: - Actions

    // MARK: - isDraftConnected
    private var isDraftConnected: Bool {
        RemoteConnectionManager.shared.connection(for: draft) != nil
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
        let manager = RemoteConnectionManager.shared
        if let existing = manager.connection(for: draft) {
            log.info("[ConnectToServer] reusing existing connection to \(draft.host)")
            manager.setActive(id: existing.id)
            onConnect?(url, password)
            return
        }
        isConnecting = true
        log.info("[ConnectToServer] connecting to \(url)")
        if scheme == "smb" || scheme == "afp" {
            onConnect?(url, password)
            isConnecting = false
        } else {
            Task {
                await manager.connect(to: draft, password: password)
                if manager.isConnected {
                    connectionError = ""
                    onConnect?(url, password)
                } else {
                    if let updated = store.servers.first(where: { $0.id == draft.id }) {
                        connectionError = updated.lastResult.rawValue
                    } else {
                        connectionError = "Connection failed"
                    }
                }
                isConnecting = false
            }
        }
    }

    // MARK: - saveAction
    private func saveAction() {
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
        selectedID = draft.id
    }

    // MARK: - disconnectAction
    private func disconnectAction() {
        let manager = RemoteConnectionManager.shared
        if let conn = manager.connection(for: draft) {
            log.info("[ConnectToServer] disconnecting from \(draft.host)")
            Task {
                await manager.disconnect(id: conn.id)
                onDisconnect?()
            }
        }
    }

    // MARK: - deleteServerAction
    private func deleteServerAction(server: RemoteServer) {
        let manager = RemoteConnectionManager.shared
        if let conn = manager.connection(for: server) {
            Task { await manager.disconnect(id: conn.id) }
        }
        RemoteServerKeychain.deletePassword(for: server)
        store.remove(server)
        onDisconnect?()
        selectFirst()
        log.info("[ConnectToServer] deleted server \(server.displayName)")
    }

    // MARK: - connectServerAction
    private func connectServerAction(server: RemoteServer) {
        draft = server
        password = RemoteServerKeychain.loadPassword(for: server)
        selectedID = server.id
        connectAction()
    }

    // MARK: - disconnectServerAction
    private func disconnectServerAction(server: RemoteServer) {
        let manager = RemoteConnectionManager.shared
        if let conn = manager.connection(for: server) {
            Task {
                await manager.disconnect(id: conn.id)
                onDisconnect?()
            }
        }
    }

    // MARK: - addNewServer
    private func addNewServer() {
        let server = RemoteServer()
        draft = server
        password = ""
        keepPassword = true
        selectedID = nil
        nameWasManuallyEdited = false
    }

    // MARK: - removeSelected
    private func removeSelected() {
        guard let id = selectedID,
              let server = store.servers.first(where: { $0.id == id }) else { return }
        store.remove(server)
        selectFirst()
    }

    // MARK: - selectFirst
    private func selectFirst() {
        if let first = store.servers.first {
            selectedID = first.id
            draft = first
            password = RemoteServerKeychain.loadPassword(for: first)
            keepPassword = !password.isEmpty
        } else {
            draft = RemoteServer()
            password = ""
        }
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

    // MARK: - sanitizeHost
    /// Removes whitespace, control characters and characters invalid in hostnames.
    private static func sanitizeHost(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: ".-_:"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
    }

    // MARK: - saveActionWithFeedback
    /// Saves bookmark via RemoteServerStore AND exports to ~/.mimi/external_sftp.json,
    /// then shows HIGAlertDialog with the result.
    private func saveActionWithFeedback() {
        saveAction()
        do {
            let filePath = try Self.exportToExternalSFTP(store: store)
            saveAlertIcon = "checkmark.circle.fill"
            saveAlertColor = .green
            saveAlertTitle = "Saved"
            saveAlertMessage = "Configuration written to\n\(filePath)"
            log.info("[ConnectToServer] exported to \(filePath)")
        } catch {
            saveAlertIcon = "xmark.circle.fill"
            saveAlertColor = .red
            saveAlertTitle = "Save Failed"
            saveAlertMessage = Self.describeError(error)
            log.error("[ConnectToServer] export failed: \(error.localizedDescription)")
        }
        showSaveAlert = true
    }

    // MARK: - exportToExternalSFTP
    /// Writes all saved servers to ~/.mimi/external_sftp.json (human-readable JSON).
    /// Returns the file path on success.
    @discardableResult
    private static func exportToExternalSFTP(store: RemoteServerStore) throws -> String {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("external_sftp.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store.servers)
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    // MARK: - describeError
    /// Provides a user-friendly error description with diagnostic hints.
    private static func describeError(_ error: Error) -> String {
        let nsErr = error as NSError
        var parts: [String] = [nsErr.localizedDescription]
        if let underlying = nsErr.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("Cause: \(underlying.localizedDescription)")
        }
        switch nsErr.domain {
        case NSCocoaErrorDomain:
            switch nsErr.code {
            case 4:   parts.append("Hint: file/directory not found.")
            case 513: parts.append("Hint: permission denied — check directory access.")
            case 640: parts.append("Hint: encoding error — data may be corrupted.")
            default:  break
            }
        case NSPOSIXErrorDomain:
            switch nsErr.code {
            case 2:  parts.append("Hint: ENOENT — path does not exist.")
            case 13: parts.append("Hint: EACCES — permission denied.")
            case 28: parts.append("Hint: ENOSPC — disk full.")
            default: break
            }
        default: break
        }
        if let recovery = nsErr.localizedRecoverySuggestion {
            parts.append(recovery)
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - iconForProtocol
    private func iconForProtocol(_ proto: RemoteProtocol) -> String {
        switch proto {
        case .sftp: return "lock.shield"
        case .ftp:  return "globe"
        case .smb:  return "externaldrive.connected.to.line.below"
        case .afp:  return "desktopcomputer"
        }
    }

    // MARK: - colorForProtocol
    private func colorForProtocol(_ proto: RemoteProtocol) -> Color {
        switch proto {
        case .sftp: return .green
        case .ftp:  return .blue
        case .smb:  return .orange
        case .afp:  return .purple
        }
    }
}
