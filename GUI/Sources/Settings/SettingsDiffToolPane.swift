// SettingsDiffToolPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - ════════════════════════════════════════════
// MARK:   Diff Tool
// MARK: - ════════════════════════════════════════════

struct SettingsDiffToolPane: View {

    @State private var registry    = DiffToolRegistry.shared
    @State private var selectedID: String? = nil
    @State private var showAddSheet  = false
    @State private var editingTool: DiffTool? = nil
    @State private var infoPopoverID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Active tool picker ───────────────────────────
            SettingsGroupBox {
                SettingsRow(label: "Active tool:",
                            help: "Tool launched by Compare button. 'Auto' picks best installed.") {
                    Picker("", selection: Binding(
                        get: { registry.activeToolID },
                        set: { registry.activeToolID = $0 }
                    )) {
                        Text("Auto (best available)").tag("auto")
                        Divider()
                        ForEach(registry.tools.filter { $0.isEnabled }) { tool in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(tool.isInstalled ? Color.green : Color.secondary.opacity(0.4))
                                    .frame(width: 7, height: 7)
                                Text(tool.name)
                                    .foregroundStyle(tool.isInstalled ? .primary : .secondary)
                            }
                            .tag(tool.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
            }

            // ── Tools list ────────────────────────────────────
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 8) {

                    Text("AVAILABLE TOOLS")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(.secondary)
                        .kerning(0.5)

                    VStack(spacing: 0) {
                        ForEach(registry.tools) { tool in
                            toolRow(tool)
                            if tool.id != registry.tools.last?.id {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                    )

                    // +/- / up/down / Edit toolbar
                    HStack(spacing: 1) {
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus").frame(width: 26, height: 20)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .help("Add custom diff tool")

                        Button {
                            if let id = selectedID { registry.remove(id: id); selectedID = nil }
                        } label: {
                            Image(systemName: "minus").frame(width: 26, height: 20)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .disabled(cannotRemove)
                        .help("Remove — only custom tools can be deleted")

                        Divider().frame(height: 16).padding(.horizontal, 6)

                        Button { if let id = selectedID { registry.moveUp(id: id) } } label: {
                            Image(systemName: "chevron.up").frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .disabled(selectedID == nil || registry.tools.first?.id == selectedID)
                        .help("Higher priority")

                        Button { if let id = selectedID { registry.moveDown(id: id) } } label: {
                            Image(systemName: "chevron.down").frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .disabled(selectedID == nil || registry.tools.last?.id == selectedID)
                        .help("Lower priority")

                        Spacer()

                        if let id = selectedID,
                           let tool = registry.tools.first(where: { $0.id == id }) {
                            Button("Edit…") { editingTool = tool }
                                .controlSize(.small).buttonStyle(.bordered)
                        }
                    }
                }
            }

            // ── No tools warning ─────────────────────────────
            if registry.tools.filter({ $0.isEnabled && $0.isInstalled }).isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text("No diff tool installed. Download DiffMerge (free) or Beyond Compare.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("DiffMerge↗") {
                        NSWorkspace.shared.open(URL(string: "https://sourcegear.com/diffmerge/")!)
                    }.controlSize(.small)
                    Button("Beyond Compare↗") {
                        NSWorkspace.shared.open(URL(string: "https://www.scootersoftware.com/")!)
                    }.controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            DiffToolEditSheet(tool: nil) { registry.add($0) }
        }
        .sheet(item: $editingTool) { tool in
            DiffToolEditSheet(tool: tool) { registry.update($0) }
        }
    }

    // MARK: - Row

    private func toolRow(_ tool: DiffTool) -> some View {
        let isSel = selectedID == tool.id
        return HStack(spacing: 10) {
            Circle()
                .fill(dotColor(tool, isSel))
                .frame(width: 8, height: 8)
                .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tool.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSel ? .white : (tool.isEnabled ? .primary : .secondary))

                    badge(tool.scope.label,
                          fg: isSel ? .white.opacity(0.7) : .secondary,
                          bg: isSel ? .white.opacity(0.2) : Color(nsColor: .separatorColor).opacity(0.6))

                    if tool.id == registry.activeToolID {
                        badge("ACTIVE",
                              fg: isSel ? .white.opacity(0.9) : .accentColor,
                              bg: isSel ? .white.opacity(0.2) : .accentColor.opacity(0.12))
                    }
                    if !tool.isInstalled {
                        badge("not found",
                              fg: isSel ? .white.opacity(0.6) : .orange,
                              bg: isSel ? .white.opacity(0.15) : .orange.opacity(0.10))
                    }
                }
                Text(tool.appPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSel ? .white.opacity(0.6) : .secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()

            // ⓘ info popover button
            Button {
                infoPopoverID = infoPopoverID == tool.id ? nil : tool.id
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(isSel ? .white.opacity(0.7) : .secondary)
            }
            .buttonStyle(.plain)
            .help("Show tool details")
            .popover(isPresented: Binding(
                get: { infoPopoverID == tool.id },
                set: { if !$0 { infoPopoverID = nil } }
            ), arrowEdge: .trailing) {
                toolInfoPopover(tool)
            }

            Toggle("", isOn: Binding(
                get: { tool.isEnabled },
                set: { _ in registry.toggleEnabled(id: tool.id) }
            ))
            .labelsHidden().toggleStyle(.checkbox)
            .disabled(!tool.isInstalled)
            .opacity(tool.isInstalled ? 1.0 : 0.4)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 7)
        .background(isSel ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedID = tool.id }
    }

    // MARK: - Helpers

    private func toolInfoPopover(_ tool: DiffTool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tool.name)
                .font(.system(size: 13, weight: .medium))
            Divider()
            infoLine("Path:", tool.appPath)
            infoLine("Arguments:", tool.arguments)
            infoLine("Scope:", tool.scope.label)
            infoLine("Status:", tool.isInstalled ? "Installed ✓" : "Not found ✗")
            if tool.isBuiltIn {
                infoLine("Type:", "Built-in preset")
            }
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
    }


    private func infoLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private var cannotRemove: Bool {
        guard let id = selectedID,
              let t  = registry.tools.first(where: { $0.id == id }) else { return true }
        return t.isBuiltIn
    }

    private func dotColor(_ t: DiffTool, _ sel: Bool) -> Color {
        if sel            { return .white }
        if !t.isInstalled { return Color(nsColor: .quaternaryLabelColor) }
        return t.isEnabled ? .green : .orange
    }

    private func badge(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .light))
            .foregroundStyle(fg)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg.cornerRadius(4))
    }
}

// MARK: - Add / Edit Sheet

struct DiffToolEditSheet: View {

    let tool:   DiffTool?
    let onSave: (DiffTool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name:      String
    @State private var appPath:   String
    @State private var arguments: String
    @State private var scope:     DiffToolScope

    init(tool: DiffTool?, onSave: @escaping (DiffTool) -> Void) {
        self.tool = tool; self.onSave = onSave
        _name      = State(initialValue: tool?.name      ?? "")
        _appPath   = State(initialValue: tool?.appPath   ?? "")
        _arguments = State(initialValue: tool?.arguments ?? #""%left" "%right""#)
        _scope     = State(initialValue: tool?.scope     ?? .both)
    }

    private var pathExists: Bool { FileManager.default.fileExists(atPath: appPath) }
    private var isValid: Bool    { !name.isEmpty && !appPath.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            Text(tool == nil ? "Add Diff Tool" : "Edit Diff Tool")
                .font(.system(size: 15, weight: .light))

            labeledField("Name:", placeholder: "e.g. Beyond Compare", text: $name)

            VStack(alignment: .leading, spacing: 4) {
                Text("Application or binary:").font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("/Applications/MyTool.app", text: $appPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Button("Browse…") { browse() }.controlSize(.small)
                }
                if !appPath.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: pathExists ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(pathExists ? Color.green : Color.orange)
                        Text(pathExists ? "Found on disk" : "Not found at this path")
                            .font(.system(size: 11))
                            .foregroundStyle(pathExists ? Color.secondary : Color.orange)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Arguments  (use %left and %right):")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                TextField(#""%left" "%right""#, text: $arguments)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text(#"Example: --nosplash "%left" "%right""#)
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Supports:").font(.system(size: 12)).foregroundStyle(.secondary)
                Picker("", selection: $scope) {
                    ForEach(DiffToolScope.allCases) { s in Text(s.label).tag(s) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button(tool == nil ? "Add" : "Save") {
                    onSave(DiffTool(
                        id:        tool?.id ?? UUID().uuidString,
                        name:      name,
                        appPath:   appPath,
                        arguments: arguments,
                        scope:     scope,
                        isBuiltIn: tool?.isBuiltIn ?? false,
                        isEnabled: tool?.isEnabled ?? true
                    ))
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.unixExecutable, .application]
        panel.message = "Choose a diff tool executable or .app bundle"
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appPath = url.path
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
    }
}

