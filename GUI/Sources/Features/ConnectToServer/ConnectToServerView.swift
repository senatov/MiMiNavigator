// ConnectToServerView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: "Connect to Server" dialog — SFTP/FTP/SMB/AFP bookmark manager.
//   Left sidebar: saved server list with +/− buttons
//   Right panel: connection form (host, user, password, port, protocol, auth type)
//   Buttons: Connect, Save, Browse
//   Matches NetworkNeighborhoodView aesthetic: .ultraThinMaterial, DialogColors

import AppKit
import SwiftUI

// MARK: - Connect to Server View
struct ConnectToServerView: View {

    var onConnect: ((URL, String) -> Void)?   // (url, password)
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

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HSplitView {
                serverSidebar
                    .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
                formPanel
                    .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 660, idealWidth: 760, minHeight: 440, idealHeight: 520)
        .background(DesignTokens.card)
        .onAppear { selectFirst() }
        .onKeyPress(.escape) { onDismiss?(); return .handled }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "server.rack").foregroundStyle(.secondary)
            Text("Connect to Server").font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DesignTokens.panelBg)
    }

    // MARK: - Left sidebar: recent sessions table
    private var serverSidebar: some View {
        VStack(spacing: 0) {
            RecentSessionsTableView(
                servers: store.servers,
                selectedID: $selectedID,
                layout: sessionLayout,
                onContextConnect: { server in connectServerAction(server: server) },
                onContextDisconnect: { server in disconnectServerAction(server: server) },
                onContextDelete: { server in deleteServerAction(server: server) }
            )
            .onChange(of: selectedID) { _, newID in
                if let id = newID, let server = store.servers.first(where: { $0.id == id }) {
                    draft = server
                    password = RemoteServerKeychain.loadPassword(for: server)
                    keepPassword = !password.isEmpty
                }
            }

            Divider()

            // +/− buttons
            HStack(spacing: 2) {
                Button { addNewServer() } label: {
                    Image(systemName: "plus").frame(width: 24, height: 20)
                }
                .buttonStyle(.plain).help("Add new server")

                Button { removeSelected() } label: {
                    Image(systemName: "minus").frame(width: 24, height: 20)
                }
                .buttonStyle(.plain).help("Remove selected server")
                .disabled(selectedID == nil)

                Spacer()
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
        }
    }

    // MARK: - Right panel: connection form
    private var formPanel: some View {
        VStack(spacing: 0) {
            // Protocol title
            Text(draft.remoteProtocol.rawValue)
                .font(.title3.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.top, 12).padding(.bottom, 8)

            Form {
                // Name
                TextField("Name:", text: $draft.name)
                    .textFieldStyle(.roundedBorder)

                // Protocol picker
                Picker("Protocol:", selection: $draft.remoteProtocol) {
                    ForEach(RemoteProtocol.allCases) { proto in
                        Text(proto.rawValue).tag(proto)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.remoteProtocol) { _, newProto in
                    if draft.port == 0 || RemoteProtocol.allCases.map(\.defaultPort).contains(draft.port) {
                        draft.port = newProto.defaultPort
                    }
                }

                // Host
                TextField("Host:", text: $draft.host)
                    .textFieldStyle(.roundedBorder)

                // User
                TextField("User:", text: $draft.user)
                    .textFieldStyle(.roundedBorder)

                // Password + eye toggle + Keep checkbox
                HStack(spacing: 6) {
                    ZStack {
                        if showPassword {
                            TextField("Password:", text: $password)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Password:", text: $password)
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

                // Port
                TextField("Port:", value: $draft.port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)

                // Remote Path
                TextField("Remote Path:", text: $draft.remotePath)
                    .textFieldStyle(.roundedBorder)

                // Auth type
                Picker("Authenticate:", selection: $draft.authType) {
                    ForEach(RemoteAuthType.allCases) { auth in
                        Text(auth.rawValue).tag(auth)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()

                // Private Key path (only for privateKey auth)
                if draft.authType == .privateKey {
                    HStack {
                        TextField("Key Path:", text: $draft.privateKeyPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Choose…") { chooseKeyFile() }
                            .controlSize(.small)
                    }
                }

                // Connect on start
                Toggle("Connect when app starts", isOn: $draft.connectOnStart)
                    .toggleStyle(.checkbox)
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            Spacer(minLength: 8)

            // Action buttons
            HStack(spacing: 12) {
                Spacer()
                if !connectionError.isEmpty {
                    Text(connectionError)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .frame(maxWidth: 200, alignment: .trailing)
                }
                if isConnecting {
                    ProgressView().scaleEffect(0.7)
                }
                Button("Connect") { connectAction() }
                    .buttonStyle(ThemedButtonStyle())
                    .disabled(draft.host.isEmpty || isConnecting)
                    .keyboardShortcut(.return, modifiers: .command)

                Button("Save") { saveAction() }
                    .disabled(draft.host.isEmpty)

                Button("Disconnect") { disconnectAction() }
                    .disabled(!isDraftConnected)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    // MARK: - Check if draft server has an active connection
    private var isDraftConnected: Bool {
        RemoteConnectionManager.shared.connection(for: draft) != nil
    }

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

        // Reuse existing connection if already connected
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

    private func saveAction() {
        if draft.name.isEmpty { draft.name = draft.host }
        // Save/update password in Keychain
        if keepPassword && !password.isEmpty {
            RemoteServerKeychain.savePassword(password, for: draft)
        } else if !keepPassword {
            RemoteServerKeychain.deletePassword(for: draft)
        }
        // Save/update server in store
        if store.servers.contains(where: { $0.id == draft.id }) {
            store.update(draft)
        } else {
            store.add(draft)
        }
        selectedID = draft.id
    }

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

    private func deleteServerAction(server: RemoteServer) {
        let manager = RemoteConnectionManager.shared
        // Disconnect if connected
        if let conn = manager.connection(for: server) {
            Task { await manager.disconnect(id: conn.id) }
        }
        // Remove from store (and keychain)
        RemoteServerKeychain.deletePassword(for: server)
        store.remove(server)
        onDisconnect?()
        selectFirst()
        log.info("[ConnectToServer] deleted server \(server.displayName)")
    }

    private func connectServerAction(server: RemoteServer) {
        draft = server
        password = RemoteServerKeychain.loadPassword(for: server)
        selectedID = server.id
        connectAction()
    }

    private func disconnectServerAction(server: RemoteServer) {
        let manager = RemoteConnectionManager.shared
        if let conn = manager.connection(for: server) {
            Task {
                await manager.disconnect(id: conn.id)
                onDisconnect?()
            }
        }
    }

    private func addNewServer() {
        let server = RemoteServer()
        draft = server
        password = ""
        keepPassword = true
        selectedID = nil  // new, unsaved
    }

    private func removeSelected() {
        guard let id = selectedID,
              let server = store.servers.first(where: { $0.id == id }) else { return }
        store.remove(server)
        selectFirst()
    }

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

    // MARK: - Icon helpers

    private func iconForProtocol(_ proto: RemoteProtocol) -> String {
        switch proto {
        case .sftp: return "lock.shield"
        case .ftp:  return "globe"
        case .smb:  return "externaldrive.connected.to.line.below"
        case .afp:  return "desktopcomputer"
        }
    }

    private func colorForProtocol(_ proto: RemoteProtocol) -> Color {
        switch proto {
        case .sftp: return .green
        case .ftp:  return .blue
        case .smb:  return .orange
        case .afp:  return .purple
        }
    }

}
