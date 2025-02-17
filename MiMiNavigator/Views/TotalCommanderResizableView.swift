//
//  TotalCommanderResizableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.

import SwiftUI

struct TotalCommanderResizableView: View {
    @State private var leftPanelWidth: CGFloat = 0
    @State private var rightPanelWidth: CGFloat = 0
    @State private var isShowMenu: Bool = UserPreferences.shared.restoreMenuState()
    @State private var selectedFile: CustomFile? = nil
    @State private var showTooltip: Bool = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""
    @ObservedObject private var fileLst = FileSingleton.shared
    @StateObject private var scanner = DualDirectoryScanner(
        leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly"),
        rightDirectory: URL(fileURLWithPath: "/Users/senat"))
    @State private var leftPath: String = ""
    @State private var rightPath: String = ""

    @State private var displayedLeftFiles: [CustomFile] = []
    @State private var displayedRightFiles: [CustomFile] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        buildTopMenuBar(geometry: geometry)
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

    // MARK: -
    private func buildTopMenuBar(geometry: GeometryProxy) -> some View {
        TopMenuBarView(isShowMenu: $isShowMenu, toggleMenu: toggleMenu)
    }

    // MARK: -
    @MainActor
    private func fetchPaths() async {
        leftPath = await scanner.leftDirectory.path
        rightPath = await scanner.rightDirectory.path
    }

    // MARK: - Fetch the files asynchronously from the actor
    @MainActor
    private func fetchLeftFiles() async {
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
    }

    // MARK: - Fetch the files asynchronously from the actor
    @MainActor
    private func fetchRightFiles() async {
        displayedRightFiles = await scanner.fileLst.getRightFiles()
    }

    // MARK: -
    private func toggleMenu() {
        LogMan.log.debug("toggleMenu()")
        withAnimation {
            isShowMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: isShowMenu)
        }
    }

    // MARK: -
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        LogMan.log.debug("buildMainPanels()")
        return HStack(spacing: 0) {
            if isShowMenu {
                builFavoriteTreeMenu()
            }
            buildLeftPanel(geometry: geometry)
            buildDivider(geometry: geometry)
            buildRightPanel(geometry: geometry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: -
    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        LogMan.log.debug("buildLeftPanel()")
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
            .frame(maxWidth: .infinity)
            .border(Color.orange)
            .onAppear {
                Task {
                    await fetchLeftFiles()
                }
            }
        }
        .frame(width: leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2) // Определяем ширину панели
    }
    // MARK: -
    private func buildRightPanel(geometry: GeometryProxy) -> some View {
        LogMan.log.debug("buildRightPanel()")
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
                Text(file.name + "x")
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity)
            .frame(
                width: rightPanelWidth == 0 ? geometry.size.width / 2 : rightPanelWidth
            )
            .onAppear {
                Task {
                    await fetchRightFiles()
                }
            }
        }
    }

    // MARK: -
    private func builFavoriteTreeMenu() -> some View {
        LogMan.log.debug("builFavoriteTreeMenu()")
        let favScanner = FavoritesScanner()
        let fileStructure = favScanner.scanFavorites()
        return TreeView(files: fileStructure, selectedFile: $selectedFile)
            .padding()  // Add padding to the tree view
            .frame(maxWidth: 230)  // Set the maximum width of the tree view
            .font(.caption)  // Use a compact font for a more condensed appearance
    }

    // MARK: -
    private func buildDivider(geometry: GeometryProxy) -> some View {
        LogMan.log.debug("buildDivider()")
        return Rectangle()
            .fill(Color.blue)
            .frame(width: 5)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDividerDrag(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        UserDefaults.standard.set(
                            leftPanelWidth, forKey: "leftPanelWidth")
                        showTooltip = false
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleClickDivider(geometry: geometry)
            }
    }

    // MARK: -
    private func handleDividerDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        LogMan.log.debug("handleDividerDrag")
        let newWidth = leftPanelWidth + value.translation.width
        if newWidth > 100 && newWidth < geometry.size.width - 100 {
            leftPanelWidth = newWidth
            let (tooltipText, tooltipPosition) = TooltipModule.calculateTooltip(
                location: value.location, dividerX: newWidth,
                totalWidth: geometry.size.width
            )
            self.tooltipText = tooltipText
            self.tooltipPosition = tooltipPosition
            showTooltip = true
        }
    }

    // MARK: -
    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }

    // MARK: -
    private func initializePanelWidth(geometry: GeometryProxy) {
        leftPanelWidth =
            UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat
            ?? geometry.size.width / 2
    }

    // MARK: -
    private func buildToolbar() -> some View {
        LogMan.log.debug("buildToolbar()")
        return HStack(spacing: 20) {
            ControlGroup {
                Button(action: {
                    LogMan.log.debug("View selected Docu")
                }) {
                    Label("F3 View", systemImage: "eye.circle")
                        .labelStyle(.titleAndIcon)
                }
                .help("View the selected document")  // Tooltip

                Button(action: {
                    LogMan.log.debug("Edit button tapped")
                }) {
                    Label("F4 Edit", systemImage: "pencil")
                        .labelStyle(.titleAndIcon)
                }
                .help("Edit the selected file")  // Tooltip

                Button(action: {
                    LogMan.log.debug("Copy button tapped")
                }) {
                    Label("F5 Copy", systemImage: "document.on.document")
                        .labelStyle(.titleAndIcon)
                }
                .help("Copy the selected file")  // Tooltip

                Button(action: {
                    LogMan.log.debug("Move button tapped")
                }) {
                    Label(
                        "F6 Move",
                        systemImage: "square.and.arrow.down.on.square"
                    )
                    .labelStyle(.titleAndIcon)
                }
                .help("Move the selected file")  // Tooltip

                Button(action: {
                    LogMan.log.debug("NewFolder button tapped")
                }) {
                    Label("F7 NewFolder", systemImage: "folder.badge.plus")
                        .labelStyle(.titleAndIcon)
                }
                .help("Create a new folder")  // Tooltip

                Button(action: {
                    LogMan.log.debug("Delete button tapped")
                }) {
                    Label("F8 Delete", systemImage: "minus.rectangle")
                        .labelStyle(.titleAndIcon)
                }
                .help("Delete the selected file")  // Tooltip

                Button(action: {
                    exitApp()
                }) {
                    Label("⌥-F4 Exit", systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                }
                .help("Exit the application")  // Tooltip

                Button(action: {
                    LogMan.log.debug("Settings button tapped")
                }) {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.titleAndIcon)
                }
                .help("Open application settings")  // Tooltip
            }
            .controlGroupStyle(.navigation)
        }
        .padding()
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }

    // MARK: -
    private func exitApp() {
        LogMan.log.debug("exitApp()")
        NSApplication.shared.terminate(nil)
    }

    // MARK: -
    private func addKeyPressMonitor() {
        LogMan.log.debug("addKeyPressMonitor()")
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
                exitApp()
                return nil
            }
            return event
        }
    }
}
