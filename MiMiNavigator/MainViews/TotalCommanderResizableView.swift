import SwiftUI

struct TotalCommanderResizableView: View {
    @State private var leftPanelWidth: CGFloat = 0
    @State private var rightPanelWidth: CGFloat = 0
    @State private var isShowMenu: Bool = UserPreferences.shared.restoreMenuState()
    @State private var selectedFile: CustomFile? = nil
    @State private var showTooltip: Bool = true
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""
    @ObservedObject private var fileLst: FileSingleton = FileSingleton.shared
    @StateObject private var scanner = DualDirScanner(
        leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly"),
        rightDirectory: URL(fileURLWithPath: "/Users/senat")
    )
    @State private var leftPath: String = ""
    @State private var rightPath: String = ""

    @State private var displayedLeftFiles: [CustomFile] = []
    @State private var displayedRightFiles: [CustomFile] = []
    @State private var fileStructure: [CustomFile] = []

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

    // MARK: - Fetch left and right directory paths
    @MainActor
    private func fetchPaths() async {
        log.debug("Fetching directory paths")
        leftPath = await scanner.leftDir.path
        rightPath = await scanner.rightDir.path
    }

    // MARK: - build main panel
    private func buildMainPanels(geometry: GeometryProxy) -> some View {
        log.debug("buildMainPanels()")
        return HStack(spacing: 0) {
            if isShowMenu {
                buildFavTreeMenu()
            }
            buildLeftPanel(geometry: geometry)
            buildDivider(geometry: geometry)
            buildRightPanel(geometry: geometry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: - Build Favorite Tree Menu Panel
    private func buildFavTreeMenu() -> some View {
        log.debug("buildFavoriteTreeMenu()")
        return TreeView(files: $fileStructure, selectedFile: $selectedFile)
            .padding()
            .frame(maxWidth: 210)
            .font(.system(size: 14, weight: .regular))
            .onAppear {
                fetchFavoriteTree()
            }
    }

    // MARK: - Build Left Panel
    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        log.debug("buildLeftPanel()")
        return VStack {
            EditPathControlWrapView(path: $leftPath)
                .onChange(of: leftPath) {
                    Task {
                        await scanner.setLeftDirectory(url: URL(fileURLWithPath: leftPath))
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
        .frame(width: leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2)
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

    // MARK: - Handle Double Click on Divider
    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }

    // MARK: -
    private func buildRightPanel(geometry: GeometryProxy) -> some View {
        log.debug("buildRightPanel()")
        return VStack {
            EditPathControlWrapView(path: $rightPath)
                .onChange(of: rightPath) {
                    Task(priority: .low) {
                        await scanner.setRightDirectory(url: URL(fileURLWithPath: rightPath))
                        await fetchRightiles()
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
            .task(priority: .low) {
                await fetchRightiles()
            }
        }
    }

    // MARK: - Build Bottom Toolbar
    private func buildDownToolbar() -> some View {
        log.debug("buildDownToolbar()")
        return HStack(spacing: 18) {
            DownToolbarButtonView(title: "F3 View", systemImage: "eye.circle") {
                log.debug("View action")
            }
            DownToolbarButtonView(title: "F4 Edit", systemImage: "pencil") {
                log.debug("Edit action")
            }
            DownToolbarButtonView(title: "F5 Copy", systemImage: "doc.on.doc") {
                log.debug("Copy action")
            }
            DownToolbarButtonView(title: "F6 Move", systemImage: "arrow.right.doc.on.clipboard") {
                log.debug("Move action")
            }
            DownToolbarButtonView(title: "F7 MkDir", systemImage: "folder.badge.plus") {
                log.debug("MkDir action")
            }
            DownToolbarButtonView(title: "F8 Delete", systemImage: "trash") {
                log.debug("Delete action")
            }
            DownToolbarButtonView(title: "Exit", systemImage: "power") {
                exitApp()
            }
        }
        .padding()
        .background(Color(.systemGray).opacity(0.05))
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
    private func initializePanelWidth(geometry: GeometryProxy) {
        if let savedWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat {
            leftPanelWidth = savedWidth
        } else {
            leftPanelWidth = geometry.size.width / 2
        }
    }

    // MARK: -
    private func fetchFavoriteTree() {
        log.debug("Fetching favorite tree structure")
        let favScanner = FavoritesScanner()
        fileStructure = favScanner.scanFavorites()
    }

    // MARK: -
    private func exitApp() {
        log.debug("exitApp()")  // Завершение приложения
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Загрузка файлов для правой панели
    @MainActor
    private func fetchRightiles() async {
        log.debug("fetch right-panel Files")
        displayedLeftFiles = await fileLst.getRightFiles()
        log.debug("fetched rightleft panel files \(displayedRightFiles.count) done")
    }

    // MARK: - Load files for the left panel
    @MainActor
    private func fetchLeftFiles() async {
        log.debug("fetch left-panel Files")
        displayedLeftFiles = await fileLst.getLeftFiles()
        log.debug("fetched left panel files \(displayedLeftFiles.count) done")
    }

    // MARK: - Toggle menu visibility
    private func toggleMenu() {
        log.debug("toggleMenu()")
        withAnimation {
            isShowMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: isShowMenu)
        }
    }

    // MARK: - Add keyboard shortcut to exit app
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
