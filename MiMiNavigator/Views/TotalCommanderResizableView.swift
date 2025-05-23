import SwiftUI

struct TotalCommanderResizableView: View {
    @StateObject var selection = SelectedDir()
    @State private var displayedLeftFiles: [CustomFile] = []
    @State private var displayedRightFiles: [CustomFile] = []
    @State private var isDividerTooltipVisible: Bool = true
    @State private var leftPanelWidth: CGFloat = 0
    @State private var leftPathStr: String = ""
    @State private var rightPathStr: String = ""
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""

    @StateObject private var scanner = DualDirectoryScanner(
        leftDirectory: SelectedDir(initialPath: "/Users/senat/Downloads/Hahly"),
        rightDirectory: SelectedDir(initialPath: "/Users/senat")
    )

    // MARK: -
    @MainActor
    private func fetchPaths() async {
        leftPathStr = await scanner.leftDirectory.path
        rightPathStr = await scanner.rightDirectory.path
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
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        TopMenuBarView()
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
            if isDividerTooltipVisible {
                PrettyTooltip(text: tooltipText)
                    .position(tooltipPosition)
                    .transition(.opacity)
                    .opacity(0.7)
                    .zIndex(1000)
            }

        }
    }

    // MARK: -
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        log.debug(#function)
        return HStack(spacing: 0) {
            buildLeftPanel(geometry: geometry)
            buildDivider(geometry: geometry)
            buildRightPanel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: -
    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        log.info(#function)
        return VStack {
            EditablePathControlWrapper(selStr: leftPathStr, selectedSide: .left)
                .onChange(of: leftPathStr) { _, newPath in
                    Task {
                        await scanner.setLeftDirectory(pathStr: newPath)
                        await fetchLeftFiles()
                    }
                }
                .cornerRadius(7)
                .padding(.horizontal, 6)
            List(displayedLeftFiles, id: \.id) { file in
                Text(file.nameStr)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
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
        log.info(#function)
        return VStack {
            EditablePathControlWrapper(selStr: rightPathStr, selectedSide: .right)
                .onChange(of: rightPathStr) { _, newPath in
                    Task(priority: .low) {
                        await scanner.setRightDirectory(pathStr: newPath)
                        await fetchRightFiles()
                    }
                }
                .cornerRadius(7)
                .padding(.horizontal, 6)
            List(displayedRightFiles, id: \.id) { file in
                Text(file.nameStr)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .border(Color.secondary)
            .onAppear {
                Task(priority: .low) {
                    await fetchRightFiles()
                }
            }
        }
    }

    // MARK: - Build Divider Between Panels
    private func buildDivider(geometry: GeometryProxy) -> some View {
        log.info(#function)
        return Rectangle()
            .fill(Color(.systemGray))
            .frame(width: 4)
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
                        isDividerTooltipVisible = false
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleClickDivider(geometry: geometry)
            }
            .onHover { isHovering in
                if isHovering {
                    DispatchQueue.main.async {
                        NSCursor.resizeLeftRight.push()
                    }
                } else {
                    DispatchQueue.main.async {
                        NSCursor.pop()
                    }
                }
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
            self.isDividerTooltipVisible = true
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
        log.info(#function)
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
            DownToolbarButtonView(
                title: "F4 Exit",
                systemImage: "power",
                action: {
                    exitApp()
                }
            )

        }
        .padding()
        .cornerRadius(7)
    }

    // MARK: -
    private func exitApp() {
        log.info(#function)
        NSApplication.shared.terminate(nil)
    }

    // MARK: -
    private func addKeyPressMonitor() {
        log.info(#function)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 0x76 {
                exitApp()
                return nil
            }
            return event
        }
    }
}
