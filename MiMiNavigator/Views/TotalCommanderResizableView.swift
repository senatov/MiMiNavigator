    //
    //  TotalCommanderResizableView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.10.24.

import SwiftUI

struct TotalCommanderResizableView: View {

    public let lineLimit = 230
    @State private var leftPanelWidth: CGFloat = 0

    @State private var isShowMenu: Bool = UserPreferences.shared.restoreMenuState()
    @State private var selectedFile: CustomFile? = nil
    @State private var showTooltip: Bool = true
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""

    @StateObject private var scanner = DualDirectoryScanner(
        leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly"),
        rightDirectory: URL(fileURLWithPath: "/Users/senat")
    )
    @State private var leftPath: String = ""
    @State private var rightPath: String = ""

    @State private var displayedLeftFiles: [CustomFile] = []
    @State private var displayedRightFiles: [CustomFile] = []
    @State private var favTreeStruct: [CustomFile] = []


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
        log.debug("toggleMenu()")
        withAnimation {
            isShowMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: isShowMenu)
        }
    }

        // MARK: -
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        log.debug("buildMainPanels()")
        return HStack(spacing: 0) {
            if isShowMenu {
                builFavTreeMenu()
            }
            buildLeftPanel(geometry: geometry)
            buildDivider(geometry: geometry)
            buildRightPanel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        TopMenuBarView(isShowMenu: $isShowMenu, toggleMenu: toggleMenu)
                        Spacer()
                    }
                    buildMainPanels(geometry: geometry)
                    buildDownToolbar()
                }
            }
            .onAppear {
                Task(priority: .low) {
                    await fetchPaths()
                }
                initializePanelWidth(geometry: geometry)
                addKeyPressMonitor()
            }
        }
    }

        // MARK: -
    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        log.debug("buildLeftPanel()")
        return VStack {
            EditablePathControlWrapper(path: $leftPath)
                .onChange(of: leftPath) { _, newPath in
                    Task {
                        await scanner.setLeftDirectory(path: newPath)
                        await fetchLeftFiles()
                    }
                }
                .cornerRadius(3)
                .padding(.horizontal, 5)
            List(displayedLeftFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .border(Color.secondary)
            .onAppear {
                Task(priority: .low) {
                    await fetchLeftFiles()
                }
            }
        }
        .frame(width: leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)  // Определяем ширину панели
    }
        // MARK: -
    private func buildRightPanel() -> some View {
        log.debug("buildRightPanel()")
        return VStack {
            EditablePathControlWrapper(path: $rightPath)
                .onChange(of: rightPath) { _, newPath in
                    Task(priority: .low) {
                        await scanner.setRightDirectory(path: newPath)
                        await fetchRightFiles()
                    }
                }
                .cornerRadius(3)
                .padding(.horizontal, 5)
            List(displayedRightFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .border(Color.secondary)
            .onAppear {
                Task(priority: .low) {
                    await fetchRightFiles()
                }
            }
        }
    }

        // MARK: -
    private func builFavTreeMenu() -> some View {
        log.debug("builFavTreeMenu()")
        return TreeView(files: $favTreeStruct, selectedFile: $selectedFile)
            .padding(3)
            .frame(maxWidth: CGFloat(lineLimit))
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundColor(Color(#colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1)))
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3), value: favTreeStruct)
            .onAppear {
                Task(priority: .background) {
                    await fetchFavTree()
                }
            }
    }

    @MainActor
    private func fetchFavTree() async {
        log.debug("fetchFavTree()")
        let favScanner = FavScanner()
        favTreeStruct = favScanner.scanFavorites()
    }

        // MARK: - Build Divider Between Panels
    private func buildDivider(geometry: GeometryProxy) -> some View {
        log.debug("buildDivider()")
        return Rectangle()
            .fill(Color(.systemGray))
            .frame(width: 2)
            .opacity(0.2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDividerDrag(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        UserDefaults.standard.set(
                            leftPanelWidth,
                            forKey: "leftPanelWidth"
                        )
                        showTooltip = false
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleClickDivider(geometry: geometry)
            }
    }

        // MARK: -
    private func handleDividerDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        log.debug("handleDividerDrag")
        let newWidth = leftPanelWidth + value.translation.width
        let minPanelWidth: CGFloat = 100
        let maxPanelWidth = geometry.size.width - 100
        if newWidth > minPanelWidth && newWidth < maxPanelWidth {
            leftPanelWidth = newWidth
            let (tooltipText, tooltipPosition) = ToolTipMod.calculateTooltip(
                location: value.location,
                dividerX: newWidth,
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
    private func buildDownToolbar() -> some View {
        log.debug("buildToolbar()")
        return HStack(spacing: 18) {  // Увеличили расстояние между кнопками
            DownToolbarButtonView(
                title: "F3 View",
                systemImage: "eye.circle",
                action: {
                    log.debug("View selected Docu")
                }
            )

            DownToolbarButtonView(
                title: "F4 Edit",
                systemImage: "pencil",
                action: {
                    log.debug("Edit button tapped")
                }
            )

            DownToolbarButtonView(
                title: "F5 Copy",
                systemImage: "document.on.document",
                action: {
                    log.debug("Copy button tapped")
                }
            )

            DownToolbarButtonView(
                title: "F6 Move",
                systemImage: "square.and.arrow.down.on.square",
                action: {
                    log.debug("Move button tapped")
                }
            )

            DownToolbarButtonView(
                title: "F7 NewFolder",
                systemImage: "folder.badge.plus",
                action: {
                    log.debug("NewFolder button tapped")
                }
            )

            DownToolbarButtonView(
                title: "F8 Delete",
                systemImage: "minus.rectangle",
                action: {
                    log.debug("Delete button tapped")
                }
            )

            DownToolbarButtonView(
                title: "F4 Exit",
                systemImage: "power",
                action: {
                    exitApp()
                }
            )

            DownToolbarButtonView(
                title: "Settings",
                systemImage: "gearshape",
                action: {
                    log.debug("Settings button tapped")
                }
            )

            DownToolbarButtonView(
                title: "Console",
                systemImage: "terminal",
                action: {
                    openConsoleInDirectory("~")
                }
            )
        }
        .padding()
        .cornerRadius(3)
    }

        // MARK: -
    private func exitApp() {
        log.debug("exitApp()")
        NSApplication.shared.terminate(nil)
    }

        // MARK: -
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
