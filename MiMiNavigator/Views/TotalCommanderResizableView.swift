//
//  TotalCommanderResizableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.

//  Description: Main view representing a Total Commander-like interface with resizable panels and a vertical tree menu.
//

import SwiftUI

/// Main view representing a Total Commander-like interface with resizable panels and a vertical tree menu.
struct TotalCommanderResizableView: View {
    @State private var leftPanelWidth: CGFloat = 0 // Set dynamically in body
    @State private var showMenu: Bool = UserPreferences.shared.restoreMenuState() // Restore menu state
    @State private var selectedFile: CustomFile? = nil // Track the selected file
    @State private var showTooltip: Bool = false // State to show/hide the tooltip
    @State private var tooltipPosition: CGPoint = .zero // Position of the tooltip
    @State private var tooltipText: String = "" // Text of the tooltip
    @ObservedObject private var fileLst = FileSingleton.shared
    @StateObject private var scanner = DualDirectoryScanner(leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly"), rightDirectory: URL(fileURLWithPath: "/Users/senat/Downloads"))
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    buildMenuButton()
                    buildMainPanels(geometry: geometry)
                    buildToolbar()
                }
                if showTooltip {
                    TooltipView(text: tooltipText, position: tooltipPosition)
                }
            }
            .onAppear {
                initializePanelWidth(geometry: geometry)
            }
        }
    }

    /// Initializes the left panel width if not restored
    private func initializePanelWidth(geometry: GeometryProxy) {
        leftPanelWidth =
            UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
    }

    /// Builds the button to open the vertical tree menu
    private func buildMenuButton() -> some View {
        HStack {
            Button(action: {
                toggleMenu() // Calls toggleMenu to save the menu state
            }) {
                Image(systemName: "line.horizontal.3")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
            .padding(4)
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.top, 8)
        .background(Color.gray.opacity(0.2))
    }

    /// Builds the main panels including the left and right panels and the draggable divider
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            if showMenu {
                buildVerticalTreeMenu()
            }
            buildLeftPanel(geometry: geometry)
            buildDivider(geometry: geometry)
            buildRightPanel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - - Toggles the menu state and saves the updated state

    private func toggleMenu() {
        withAnimation {
            showMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: showMenu) // Save menu state
        }
    }

    // MARK: - - Builds the vertical tree menu

    private func buildVerticalTreeMenu() -> some View {
        log.debug("buildVerticalTreeMenu")
        let scanner = FavoritesScanner()
        let fileStructure = scanner.scanFavorites() // Replaces static file structure with the scanned favorites structure

        return TreeView(files: fileStructure, selectedFile: $selectedFile)
            .padding()
            .frame(maxWidth: 200)
            .background(Color.gray.opacity(0.1))
    }

    // MARK: - - Builds the left panel containing a list of files

    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        log.debug("buildLeftPanel")
        return VStack {
            List(fileLst.leftFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(width: leftPanelWidth == 0 ? geometry.size.width / 2 : leftPanelWidth)
            .border(Color.gray)
        }
    }

    // MARK: - - Builds the right panel containing a list of files

    private func buildRightPanel() -> some View {
        log.debug("buildRightPanel")
        return VStack {
            List(fileLst.rightFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity) // Опционально для адаптивной ширины
            .border(Color.gray)
        }
    }

    // MARK: - - Builds the draggable divider between the panels

    private func buildDivider(geometry: GeometryProxy) -> some View {
        log.debug("buildDivider")
        return Rectangle()
            .fill(Color.gray)
            .frame(width: 5)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDividerDrag(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
                        showTooltip = false
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleClickDivider(geometry: geometry)
            }
    }

    // MARK: - - Handles the drag gesture for the divider

    private func handleDividerDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        log.debug("handleDividerDrag")
        let newWidth = leftPanelWidth + value.translation.width
        if newWidth > 100 && newWidth < geometry.size.width - 100 {
            leftPanelWidth = newWidth
            let (tooltipText, tooltipPosition) = TooltipModule.calculateTooltip(
                location: value.location, dividerX: newWidth, totalWidth: geometry.size.width)
            self.tooltipText = tooltipText
            self.tooltipPosition = tooltipPosition
            showTooltip = true
        }
    }

    // MARK: - - Builds the bottom toolbar with various actions

    private func buildToolbar() -> some View {
        HStack {
            ToolbarButton(title: "F3 View", icon: "eye.circle") { print("View selected Docu") }
            ToolbarButton(title: "F4 Edit", icon: "pencil") { print("Edit button tapped") }
            ToolbarButton(title: "F5 Copy", icon: "document.on.document") { print("Copy button tapped") }
            ToolbarButton(title: "F6 Move", icon: "folder.move") { print("Move button tapped") }
            ToolbarButton(title: "F7 NewFolder", icon: "folder.badge.plus") { print("NewFolder button tapped") }
            ToolbarButton(title: "F8 Delete", icon: "minus.rectangle") { print("Delete button tapped") }
            ToolbarButton(title: "Alt-F4 Exit", icon: "pip.exit") { print("Exit button tapped") }
            Spacer()
            ToolbarButton(title: "Console", icon: "terminal") {
                openConsoleInDirectory("~")
            } // Console button added to toolbar
            ToolbarButton(title: "Settings", icon: "opticid") { print("Settings button tapped") }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }

    // MARK: - - Handles double-click on the divider to reset the left panel width

    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }
}
