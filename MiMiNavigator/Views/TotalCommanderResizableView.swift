//
//  TotalCommanderResizableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 17.10.24.
//
// Description:

import SwiftUI
import SwiftyBeaver

struct TotalCommanderResizableView: View {
    @ObservedObject var directoryMonitor: DualDirectoryMonitor
    @State private var leftPanelWidth: CGFloat = 0
    @State private var showMenu: Bool = UserPreferences.shared.restoreMenuState()
    @State private var selectedFile: CustomFile? = nil
    @State private var showTooltip: Bool = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""
    @State private var leftFiles: [CustomFile] = [] // Local state for left files
    @State private var rightFiles: [CustomFile] = [] // Local state for right files
    let log = SwiftyBeaver.self

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
                Task {
                    self.leftFiles = await directoryMonitor.getLeftFiles()
                    self.rightFiles = await directoryMonitor.getRightFiles()
                    await directoryMonitor.startMonitoring()
                }
            }
            .onDisappear {
                Task {
                    await directoryMonitor.stopMonitoring()
                }
            }
        }
    }

    private func initializePanelWidth(geometry: GeometryProxy) {
        leftPanelWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
    }

    private func buildMenuButton() -> some View {
        HStack {
            Button(action: {
                toggleMenu()
            }) {
                Image(systemName: "sidebar.leading")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.top, 8)
        .background(Color.gray.opacity(0.2))
    }

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

    private func toggleMenu() {
        withAnimation {
            showMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: showMenu)
        }
    }

    private func buildVerticalTreeMenu() -> some View {
        TreeView(files: FavoritesPanel().getFavoriteItems().map { CustomFile(name: $0.name, path: "", isDirectory: true, children: nil) },
                 selectedFile: $selectedFile)
            .padding()
            .frame(maxWidth: 200)
            .background(Color.gray.opacity(0.1))
    }

    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        VStack {
            if leftFiles.isEmpty {
                Text("No files available")
                    .foregroundColor(.gray)
            } else {
                AnyView(List(leftFiles, id: \.id) { file in
                    Text(file.name)
                        .contextMenu {
                            FileContextMenu()
                        }
                }
                .listStyle(PlainListStyle()))
            }
        }
        .frame(width: leftPanelWidth == 0 ? geometry.size.width / 2 : leftPanelWidth)
        .border(Color.gray)
    }

    private func buildRightPanel() -> some View {
        VStack {
            if rightFiles.isEmpty {
                Text("No files available")
                    .foregroundColor(.gray)
            } else {
                AnyView(List(rightFiles, id: \.id) { file in
                    Text(file.name)
                        .contextMenu {
                            FileContextMenu()
                        }
                }
                .listStyle(PlainListStyle()))
            }
        }
        .border(Color.gray)
    }

    private func buildDivider(geometry: GeometryProxy) -> some View {
        Rectangle()
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

    private func handleDividerDrag(value: DragGesture.Value, geometry: GeometryProxy) {
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

    private func buildToolbar() -> some View {
        HStack {
            ToolbarButton(title: "Copy", icon: "document.on.document") {
                log.debug("Copy button tapped")
            }
            ToolbarButton(title: "Move", icon: "trash") {
                log.debug("Move button tapped")
            }
            ToolbarButton(title: "Delete", icon: "eraser.line.dashed") {
                log.debug("Delete button tapped")
            }
            Spacer()
            ToolbarButton(title: "Console", icon: "apple.terminal") {
                openConsoleInDirectory("~")
            }
            ToolbarButton(title: "Settings", icon: "blinds.horizontal.open") {
                log.debug("Settings button tapped")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }

    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }
}
