//
//  TotalCommanderResizableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.

import SwiftUI

struct TotalCommanderResizableView: View {
    @State private var leftPanelWidth: CGFloat = 0
    @State private var isShowMenu: Bool = UserPreferences.shared.restoreMenuState()
    @State private var selectedFile: CustomFile? = nil
    @State private var showTooltip: Bool = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""
    @ObservedObject private var fileLst = FileSingleton.shared
    @StateObject private var scanner = DualDirectoryScanner(leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly"),
                                                            rightDirectory: URL(fileURLWithPath: "/TMP"))
    @State private var leftPath: String = ""
    @State private var rightPath: String = ""

    @State private var displayedLeftFiles: [CustomFile] = []
    @State private var displayedRightFiles: [CustomFile] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        buildMenuButton(geometry: geometry)
                        Spacer()
                    }
                    buildMainPanels(geometry: geometry)
                    buildToolbar()
                }
                if showTooltip {
                    TooltipView(text: tooltipText, position: tooltipPosition)
                }
            }
            .onAppear {
                Task {
                    await fetchPaths()
                }
                initializePanelWidth(geometry: geometry)
                addKeyPressMonitor()
            }
        }
    }

    // MARK: - -

    @MainActor
    private func fetchPaths() async {
        leftPath = await scanner.leftDirectory.path
        rightPath = await scanner.rightDirectory.path
    }

    // MARK: - - Fetch the files asynchronously from the actor

    @MainActor
    private func fetchLeftFiles() async {
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
    }

    // MARK: - - Fetch the files asynchronously from the actor

    @MainActor
    private func fetchRightFiles() async {
        displayedRightFiles = await scanner.fileLst.getRightFiles()
    }

    // MARK: - -

    private func toggleMenu() {
        log.debug("toggleMenu()")
        withAnimation {
            isShowMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: isShowMenu)
        }
    }

    // MARK: - -

    private func buildMenuButton(geometry: GeometryProxy) -> some View {
        log.debug("buildMenuButton()")
        return HStack {
            Button(action: { toggleMenu() }) {
                Image(systemName: "line.horizontal.3")
                    .foregroundColor(.black)
                    .font(.title2)
                    .padding(8)
            }
            .background(Color.clear)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
            .shadow(color: Color.white.opacity(0.7), radius: 4, x: -2, y: -2)
            .buttonStyle(.borderless)
        }
        .padding(.leading, 0.1)
        .padding(.bottom, 0.1)
    }

    // MARK: - -

    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        log.debug("buildMainPanels()")
        return HStack(spacing: 0) {
            if isShowMenu {
                builFavoriteTreeMenu()
            }
            buildLeftPanel(geometry: geometry)
            buildDivider(geometry: geometry)
            buildRightPanel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: - -

    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        log.debug("buildLeftPanel()")
        return VStack {
            EditablePathControlWrapper(path: $leftPath)
                .padding(.bottom, 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.8), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                )
                .padding(.bottom, 4)
                .onChange(of: leftPath) { _, newPath in
                    Task {
                        await scanner.setLeftDirectory(path: newPath)
                        await fetchLeftFiles()
                    }
                }

            List(displayedLeftFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(width: leftPanelWidth == 0 ? geometry.size.width / 2 : leftPanelWidth)
            .border(Color.gray)
            .onAppear {
                Task {
                    await fetchLeftFiles()
                }
            }
        }
    }

    // MARK: - -

    private func buildRightPanel() -> some View {
        log.debug("buildRightPanel()")
        return VStack {
            EditablePathControlWrapper(path: $rightPath)
                .padding(.bottom, 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.8), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                )
                .padding(.bottom, 4)
                .onChange(of: rightPath) { _, newPath in
                    Task {
                        await scanner.setRightDirectory(path: newPath)
                        await fetchRightFiles()
                    }
                }

            List(displayedRightFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity)
            .border(Color.gray)
            .onAppear {
                Task {
                    await fetchRightFiles()
                }
            }
        }
    }

    // MARK: - -

    private func builFavoriteTreeMenu() -> some View {
        log.debug("builFavoriteTreeMenu()") // Log the start of the menu-building process
        let favScanner = FavoritesScanner() // Initialize the favorites scanner
        let fileStructure = favScanner.scanFavorites() // Scan and retrieve the file structure
        return TreeView(files: fileStructure, selectedFile: $selectedFile)
            .padding() // Add padding to the tree view
            .frame(maxWidth: 230) // Set the maximum width of the tree view
            .font(.caption) // Use a compact font for a more condensed appearance
    }

    // MARK: - -

    private func buildDivider(geometry: GeometryProxy) -> some View {
        log.debug("buildDivider()")
        return Rectangle()
            .fill(Color.gray)
            .frame(width: 7)
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

    // MARK: - -

    private func handleDividerDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        log.debug("handleDividerDrag")
        let newWidth = leftPanelWidth + value.translation.width
        if newWidth > 100 && newWidth < geometry.size.width - 100 {
            leftPanelWidth = newWidth
            let (tooltipText, tooltipPosition) = TooltipModule.calculateTooltip(
                location: value.location, dividerX: newWidth, totalWidth: geometry.size.width
            )
            self.tooltipText = tooltipText
            self.tooltipPosition = tooltipPosition
            showTooltip = true
        }
    }

    // MARK: - -

    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }

    // MARK: - -

    private func initializePanelWidth(geometry: GeometryProxy) {
        leftPanelWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
    }

    // MARK: - -

    private func buildToolbar() -> some View {
        log.debug("buildToolbar()")
        let buttons = [
            ("F3 View", "eye.circle", { log.debug("View selected Docu") }),
            ("F4 Edit", "pencil", { log.debug("Edit button tapped") }),
            ("F5 Copy", "document.on.document", { log.debug("Copy button tapped") }),
            ("F6 Move", "square.and.arrow.down.on.square", { log.debug("Move button tapped") }),
            ("F7 NewFolder", "folder.badge.plus", { log.debug("NewFolder button tapped") }),
            ("F8 Delete", "minus.rectangle", { log.debug("Delete button tapped") }),
            ("⌥-F4 Exit", "pip.exit", { exitApp() }),
        ]

        return HStack(spacing: 2) {
            ForEach(buttons, id: \.0) { title, icon, action in
                TB_Button_IS(title: title, icon: icon, action: action)
                    .buttonStyle(.bordered)
                if title == "⌥-F4 Exit" {
                    Spacer()
                }
            }
            TB_Button_IS(title: "Console", icon: "terminal") {
                openConsoleInDirectory("~")
            }
            .buttonStyle(.bordered)

            TB_Button_IS(title: "Settings", icon: "switch.2") {
                log.debug("Settings button tapped")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - -

    private func exitApp() {
        log.debug("exitApp()")
        NSApplication.shared.terminate(nil)
    }

    // MARK: - -

    private func addKeyPressMonitor() {
        log.debug("addKeyPressMonitor()")
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
                exitApp()
                return nil
            }
            return event
        }
    }
}
