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
    var onDismiss: (() -> Void)?

    @State private var store = RemoteServerStore.shared
    @State private var selectedID: RemoteServer.ID?
    @State private var draft = RemoteServer()
    @State private var password: String = ""
    @State private var keepPassword: Bool = true
    @State private var isConnecting: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HSplitView {
                serverSidebar
                    .frame(minWidth: 140, idealWidth: 170, maxWidth: 220)
                formPanel
                    .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 440, idealHeight: 520)
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

    // MARK: - Left sidebar: saved servers
    private var serverSidebar: some View {
        VStack(spacing: 0) {
            Text("Recent").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

            List(store.servers, selection: $selectedID) { server in
                HStack(spacing: 6) {
                    Image(systemName: iconForProtocol(server.remoteProtocol))
                        .foregroundStyle(colorForProtocol(server.remoteProtocol))
                        .font(.system(size: 13))
                    Text(server.displayName)
                        .font(.callout).lineLimit(1)
                }
                .tag(server.id)
            }
            .listStyle(.sidebar)
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

                // Password + Keep checkbox
                HStack {
                    SecureField("Password:", text: $password)
                        .textFieldStyle(.roundedBorder)
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
                if isConnecting {
                    ProgressView().scaleEffect(0.7)
                }
                Button("Connect") { connectAction() }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.host.isEmpty || isConnecting)
                    .keyboardShortcut(.return, modifiers: .command)

                Button("Save") { saveAction() }
                    .disabled(draft.host.isEmpty)

                Button("Browse") { browseAction() }
                    .disabled(draft.host.isEmpty)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    private func connectAction() {
        saveAction()
        guard let url = draft.connectionURL else {
            log.warning("[ConnectToServer] invalid URL for '\(draft.host)'")
            return
        }
        isConnecting = true
        log.info("[ConnectToServer] connecting to \(url)")
        onConnect?(url, password)
        // Coordinator will close on success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isConnecting = false
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

    private func browseAction() {
        // Open in Finder via URL scheme
        guard let url = draft.connectionURL else { return }
        NSWorkspace.shared.open(url)
        log.info("[ConnectToServer] browse \(url)")
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
