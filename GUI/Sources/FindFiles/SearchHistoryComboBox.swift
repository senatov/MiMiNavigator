// SearchHistoryComboBox.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: NSComboBox wrapper for SwiftUI — shows history dropdown with editable text field

import AppKit
import SwiftUI

// MARK: - Search History ComboBox
/// SwiftUI wrapper around NSComboBox with history dropdown
struct SearchHistoryComboBox: NSViewRepresentable {
    @Binding var text: String
    let historyKey: SearchHistoryManager.HistoryKey
    let placeholder: String
    var onSubmit: (() -> Void)?

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.isEditable = true
        comboBox.completes = true
        comboBox.hasVerticalScroller = true
        comboBox.numberOfVisibleItems = 12
        comboBox.placeholderString = placeholder
        comboBox.usesDataSource = false
        comboBox.delegate = context.coordinator
        comboBox.font = NSFont.systemFont(ofSize: 13)
        comboBox.isBordered = true
        comboBox.isBezeled = true
        comboBox.bezelStyle = .roundedBezel

        // Blue border
        comboBox.wantsLayer = true
        comboBox.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
        comboBox.layer?.borderWidth = 1.0
        comboBox.layer?.cornerRadius = 4.0

        // Load history
        let items = SearchHistoryManager.shared.history(for: historyKey)
        comboBox.removeAllItems()
        comboBox.addItems(withObjectValues: items)
        comboBox.stringValue = text

        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }
        // Refresh history items
        let items = SearchHistoryManager.shared.history(for: historyKey)
        comboBox.removeAllItems()
        comboBox.addItems(withObjectValues: items)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSComboBoxDelegate, NSTextFieldDelegate {
        let parent: SearchHistoryComboBox

        init(_ parent: SearchHistoryComboBox) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else { return }
            parent.text = comboBox.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else { return }
            parent.text = comboBox.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            // Delay to let NSComboBox update its stringValue
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = comboBox.stringValue
            }
        }

        // Handle Enter key
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.text = (control as? NSComboBox)?.stringValue ?? parent.text
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}
