// CreateFileDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: SwiftUI HIG-style Create New File dialog

import AppKit
import SwiftUI

// MARK: - Create File Dialog
/// SwiftUI HIG-style dialog matching CreateFolderDialog behavior.
struct CreateFileDialog: View {
    let parentURL: URL
    let onCreateFile: (String) -> Void
    let onCancel: () -> Void

    @State private var fileName: String
    @State private var errorMessage: String?

    init(
        parentURL: URL,
        onCreateFile: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.parentURL = parentURL
        self.onCreateFile = onCreateFile
        self.onCancel = onCancel
        self._fileName = State(initialValue: L10n.Dialog.CreateFile.defaultName)
    }

    private var isValidName: Bool {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let invalidChars = CharacterSet(charactersIn: ":/\\")
        return trimmed.rangeOfCharacter(from: invalidChars) == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HIGDialogHeader(
                L10n.Dialog.CreateFile.title,
                subtitle: parentURL.path
            )
            .frame(maxWidth: .infinity)

            nameField

            if !fileName.isEmpty && !isValidName {
                Text(L10n.Error.fileNameInvalidCharsExtended)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            buttonRow
        }
        .higDialogStyle()
        .frame(minWidth: 380)
    }

    // MARK: - nameField
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Dialog.CreateFile.enterNameLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            CreateFileNameField(
                text: $fileName,
                placeholder: L10n.Dialog.CreateFile.placeholder,
                onSubmit: performCreate
            )
            .frame(height: 19)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(nameFieldBorder)
        }
    }

    // MARK: - nameFieldBorder
    private var nameFieldBorder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(
                !isValidName && !fileName.isEmpty ? Color.red.opacity(0.7) : Color(nsColor: .separatorColor),
                lineWidth: 1
            )
    }

    // MARK: - buttonRow
    private var buttonRow: some View {
        HStack(spacing: 10) {
            Spacer()
            DownToolbarButtonView(title: L10n.Button.cancel, systemImage: "xmark", action: onCancel)
                .keyboardShortcut(.cancelAction)
            DownToolbarButtonView(title: L10n.Button.create, systemImage: "doc.badge.plus", action: performCreate)
                .disabled(!isValidName)
                .opacity(isValidName ? 1.0 : 0.55)
        }
        .padding(.top, 6)
    }

    // MARK: - performCreate
    private func performCreate() {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.Error.fileNameEmpty
            return
        }
        guard isValidName else {
            errorMessage = L10n.Error.fileNameInvalidCharsExtended
            return
        }
        onCreateFile(trimmed)
    }
}

// MARK: - CreateFileNameField
private struct CreateFileNameField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    // MARK: - makeCoordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    // MARK: - makeNSView
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 14)
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.usesSingleLineMode = true
        textField.delegate = context.coordinator
        context.coordinator.attach(textField)
        return textField
    }

    // MARK: - updateNSView
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.attach(nsView)
    }
}

// MARK: - CreateFileNameField Coordinator
extension CreateFileNameField {
    @MainActor
    fileprivate final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        private let onSubmit: () -> Void
        private weak var textField: NSTextField?
        private var didScheduleInitialFocus = false
        private var didSelectInitialText = false
        private var canSubmitFromKeyboard = false

        // MARK: - init
        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }

        // MARK: - attach
        func attach(_ textField: NSTextField) {
            self.textField = textField
            scheduleInitialFocusIfNeeded()
        }

        // MARK: - controlTextDidChange
        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text = textField.stringValue
        }

        // MARK: - control
        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            text = textField?.stringValue ?? text
            guard canSubmitFromKeyboard else { return true }
            submit()
            return true
        }

        // MARK: - submit
        private func submit() {
            text = textField?.stringValue ?? text
            onSubmit()
        }

        // MARK: - scheduleInitialFocusIfNeeded
        private func scheduleInitialFocusIfNeeded() {
            guard !didScheduleInitialFocus else { return }
            didScheduleInitialFocus = true
            for delay in [0.0, 0.05, 0.15] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.focusAndSelectText()
                }
            }
        }

        // MARK: - focusAndSelectText
        private func focusAndSelectText() {
            guard let textField, let window = textField.window else { return }
            window.makeFirstResponder(textField)
            guard !didSelectInitialText else { return }
            textField.selectText(nil)
            didSelectInitialText = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.canSubmitFromKeyboard = true
            }
            log.debug("[CreateFile] focused name field and selected default name")
        }
    }
}

// MARK: - Preview
#Preview {
    CreateFileDialog(
        parentURL: URL(fileURLWithPath: "/Users/test/Documents"),
        onCreateFile: { _ in },
        onCancel: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
