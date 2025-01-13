    //
    //  TopMenuBarView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.10.24.
    //

import SwiftUI

struct TopMenuBarView: View {
        // MARK: - Properties
    @Binding var isShowMenu: Bool
    var toggleMenu: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            menuButton(
                icon: "line.horizontal.3",
                action: toggleMenu,
                accessibilityLabel: "Toggle Menu"
            )
            menuSection(title: "Files", icon: "externaldrive.connected.to.line.below", menuItems: filesMenuItems)
            menuSection(title: "Mark", icon: "pencil.circle", menuItems: markMenuItems)
            menuSection(title: "Commands", icon: "doc.on.doc", menuItems: commandMenuItems)
            menuSection(title: "Net", icon: "network", menuItems: netMenuItems)
            menuSection(title: "Show", icon: "dot.circle.viewfinder", menuItems: showMenuItems)
            menuSection(title: "Configuration", icon: "gear.circle", menuItems: configMenuItems)
            menuSection(title: "Start", icon: "figure.run.circle", menuItems: startMenuItems)
            menuSection(title: "Help", icon: "questionmark.circle", menuItems: helpMenuItems)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

        // MARK: - Menu Items Definitions
    private var filesMenuItems: [MenuItem] {
        [
            .init(title: "Rename/Move", action: {}),
            .init(title: "Change Attributes...", action: {}),
            .init(title: "Pack...", action: {}),
            .init(title: "Unpack...", action: {}),
            .init(title: "Test Archive(s)", action: {}),
            .init(title: "Compare By Content...", action: {}),
            .init(title: "Synchronize Directories...", action: {}),
            .init(title: "Associate With...", action: {}),
            .init(title: "Calculate Occupied Space...", action: {}),
            .init(title: "Multi-Rename Tool...", action: {}),
            .init(title: "Edit Comment...", action: {}),
            .init(title: "Verify Checksums...", action: {}),
            .init(title: "Create Checksum File(s)...", action: {}),
            .init(title: "Print...", action: {}),
            .init(title: "Split File...", action: {}),
            .init(title: "Combine Files...", action: {}),
            .init(title: "Quit", action: {})
        ]
    }

    private var markMenuItems: [MenuItem] {
        [
            .init(title: "Select Group...", action: {}),
            .init(title: "Unselect Group...", action: {}),
            .init(title: "Select All", action: {}),
            .init(title: "Unselect All", action: {}),
            .init(title: "Invert Selection", action: {}),
            .init(title: "Save Selection...", action: {}),
            .init(title: "Load Selection...", action: {})
        ]
    }

    private var commandMenuItems: [MenuItem] {
        [
            .init(title: "Open Command Prompt...", action: {}),
            .init(title: "Open Desktop Folder", action: {}),
            .init(title: "Open Terminal Here...", action: {}),
            .init(title: "CD Tree...", action: {}),
            .init(title: "Branch View (With Subdirs)", action: {}),
            .init(title: "Volume Label...", action: {}),
            .init(title: "Compare Directories...", action: {}),
            .init(title: "Search Files...", action: {}),
            .init(title: "Search in Separate Process...", action: {}),
            .init(title: "Hot Directory List...", action: {})
        ]
    }

    private var netMenuItems: [MenuItem] {
        [
            .init(title: "FTP Connect...", action: {}),
            .init(title: "FTP Disconnect", action: {}),
            .init(title: "FTP Show Hidden Files", action: {}),
            .init(title: "Reconnect to Server", action: {}),
            .init(title: "Network Neighborhood", action: {})
        ]
    }

    private var showMenuItems: [MenuItem] {
        [
            .init(title: "Full View", action: {}),
            .init(title: "Brief View", action: {}),
            .init(title: "Tree View", action: {}),
            .init(title: "Quick View", action: {}),
            .init(title: "Hidden Files", action: {})
        ]
    }

    private var configMenuItems: [MenuItem] {
        [
            .init(title: "Options...", action: {}),
            .init(title: "Save Settings", action: {}),
            .init(title: "Restore Settings", action: {}),
            .init(title: "Customize Toolbar...", action: {})
        ]
    }

    private var startMenuItems: [MenuItem] {
        [
            .init(title: "New Tab", action: {}),
            .init(title: "Duplicate Tab", action: {}),
            .init(title: "Close Tab", action: {}),
            .init(title: "Close All Tabs", action: {}),
            .init(title: "Start Application", action: {}),
            .init(title: "Restart Services", action: {})
        ]
    }

    private var helpMenuItems: [MenuItem] {
        [
            .init(title: "Contents", action: {}),
            .init(title: "Keyboard Shortcuts", action: {}),
            .init(title: "Check for Updates...", action: {}),
            .init(title: "About...", action: {}),
            .init(title: "Contact Support", action: {})
        ]
    }

        // MARK: - Components
    private func menuButton(icon: String, action: @escaping () -> Void, accessibilityLabel: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.black)
                .font(.title2)
                .padding(8)
        }
        .accessibilityLabel(accessibilityLabel)
        .background(Color.clear)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
        .shadow(color: Color.white.opacity(0.7), radius: 4, x: -2, y: -2)
        .buttonStyle(.borderless)
    }

    private func menuSection(title: String, icon: String, menuItems: [MenuItem]) -> some View {
        Menu {
            ForEach(menuItems) { item in
                Button(item.title, action: item.action)
            }
        } label: {
            Label(title, systemImage: icon)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 5)
    }
}

    // MARK: - Supporting Structures
struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
}
