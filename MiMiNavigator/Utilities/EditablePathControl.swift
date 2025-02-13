//
//  EditablePathControl.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import AppKit
import SwiftUI

struct EditablePathControl: NSViewRepresentable {
    @Binding var path: String
    var onPathSelected: (String) -> Void
    @State private var isEditing = false

    func makeNSView(context: Context) -> NSPathControl {
        LogMan.log.debug("makeNSView()")
        let pathControl = NSPathControl()
        pathControl.target = context.coordinator
        pathControl.action = #selector(Coordinator.pathControlDidChange(_:))
        pathControl.pathStyle = .standard
        // Directly set URL without `if let`
        pathControl.url = URL(fileURLWithPath: path)
        return pathControl
    }

    func updateNSView(_ nsView: NSPathControl, context: Context) {
        nsView.url = URL(fileURLWithPath: path)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPathSelected: onPathSelected)
    }
}
