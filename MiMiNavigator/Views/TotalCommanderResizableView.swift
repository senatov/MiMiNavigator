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
    @State private var isShowMenu: Bool = UserPreferences.shared.restoreMenuState() // Restore menu state
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
                addKeyPressMonitor()
            }
        }
    }

    /// Initializes the left panel width if not restored
    private func initializePanelWidth(geometry: GeometryProxy) {
        leftPanelWidth =
            UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
    }

    fileprivate func getRightPathLine() -> some View {
        TextField("", text: .constant("/abc/scde/.ggg/qqqq"))
            .textFieldStyle(PlainTextFieldStyle()) // Plain стиль для упрощённого вида
            .padding(8)
            .background(Color.blue.opacity(0.1)) // Светло-синий фон
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray, lineWidth: 1) // Рамка серого цвета
            )
            .frame(maxWidth: .infinity)
    }
    
    fileprivate func getLeftPathLine() -> some View {
        TextField("", text: .constant("/xxx/asdfg/65.gf/aaaa"))
            .textFieldStyle(PlainTextFieldStyle())
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
    }
    
    private func buildMenuButton() -> some View {

        HStack {
            VStack(alignment: .leading) {
                Button(action: {
                    toggleMenu() // Calls toggleMenu to save the menu state
                }) {
                    Image(systemName: "line.horizontal.3")
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            Spacer()
            getLeftPathLine()
            Spacer()
            getRightPathLine()
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(Color.gray.opacity(0.4))
    }

    /// Builds the main panels including the left and right panels and the draggable divider
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            if isShowMenu {
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
            isShowMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: isShowMenu) // Save menu state
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
        let buttons = [
            ("F3 View", "eye.circle", { log.debug("View selected Docu") }),
            ("F4 Edit", "pencil", { log.debug("Edit button tapped") }),
            ("F5 Copy", "document.on.document", { log.debug("Copy button tapped") }),
            ("F6 Move", "square.and.arrow.down.on.square", { log.debug("Move button tapped") }),
            ("F7 NewFolder", "folder.badge.plus", { log.debug("NewFolder button tapped") }),
            ("F8 Delete", "minus.rectangle", { log.debug("Delete button tapped") }),
            ("⌥-F4 Exit", "pip.exit", { exitApp() }),
        ]

        return HStack {
            ForEach(buttons, id: \.0) { title, icon, action in
                ToolbarButton(title: title, icon: icon, action: action)
                    .buttonStyle(.bordered)
                if title == "⌥-F4 Exit" {
                    Spacer()
                }
            }
            ToolbarButton(title: "Console", icon: "terminal") {
                openConsoleInDirectory("~")
            }.buttonStyle(.bordered)

            ToolbarButton(title: "Settings", icon: "switch.2") {
                log.debug("Settings button tapped")
            }.buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func exitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func addKeyPressMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
                // 0x76 - код клавиши F4
                exitApp()
                return nil
            }
            return event
        }
    }

    // MARK: - - Handles double-click on the divider to reset the left panel width

    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }
}
