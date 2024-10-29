    //
    //  TotalCommanderResizableView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 17.10.24.
    //

import SwiftUI

    // MARK: - Total Commander-like Menu Structure

struct MenuOption: Identifiable {
    let id = UUID()
    let name: String
    var children: [MenuOption]? = nil
}

let menuOptions: [MenuOption] = [
    MenuOption(name: "Configuration", children: [
        MenuOption(name: "Options"),
        MenuOption(name: "Display"),
        MenuOption(name: "Layout"),
        MenuOption(name: "Colors"),
        MenuOption(name: "Fonts")
    ]),
    MenuOption(name: "Files", children: [
        MenuOption(name: "Associate"),
        MenuOption(name: "Edit/View"),
        MenuOption(name: "Compare"),
        MenuOption(name: "Sync Dirs")
    ]),
    MenuOption(name: "Network", children: [
        MenuOption(name: "FTP Connect"),
        MenuOption(name: "FTP Disconnect"),
        MenuOption(name: "Network Neighborhood")
    ]),
    MenuOption(name: "Tools", children: [
        MenuOption(name: "Multi-Rename Tool"),
        MenuOption(name: "Disk Cleanup"),
        MenuOption(name: "Compare by Content")
    ])
]

    // MARK: - TotalCommanderResizableView

struct TotalCommanderResizableView: View {
    @ObservedObject var directoryMonitor: DualDirectoryMonitor
    @State private var leftPanelWidth: CGFloat = 0
    @State private var showMenu: Bool = UserPreferences.shared.restoreMenuState()
    @State private var selectedFile: CustomFile? = nil
    @State private var showTooltip: Bool = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipText: String = ""
    
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
        // MARK: -
    private func initializePanelWidth(geometry: GeometryProxy) {
        leftPanelWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
    }
        // MARK: -
    private func buildMenuButton() -> some View {
        HStack {
            Button(action: {
                toggleMenu()
            }) {
                Image(systemName: "line.horizontal.3")
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
        // MARK: -
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
        // MARK: -
    private func toggleMenu() {
        withAnimation {
            showMenu.toggle()
            UserPreferences.shared.saveMenuState(isOpen: showMenu)
        }
    }
        // MARK: - 
    private func buildVerticalTreeMenu() -> some View {
        TreeView(files: menuOptions.map { CustomFile(name: $0.name, path: "", isDirectory: true, children: $0.children?.map { CustomFile(name: $0.name, path: "", isDirectory: true, children: nil) }) }, selectedFile: $selectedFile)
            .padding()
            .frame(maxWidth: 200)
            .background(Color.gray.opacity(0.1))
    }
    
    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        VStack {
            List(directoryMonitor.leftFiles, id: \.id) { file in
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
    
    private func buildRightPanel() -> some View {
        VStack {
            List(directoryMonitor.rightFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        FileContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .border(Color.gray)
        }
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
                print("Copy button tapped")
            }
            ToolbarButton(title: "Move", icon: "trash") {
                print("MOVE button tapped")
            }
            ToolbarButton(title: "Delete", icon: "eraser") {
                print("DELETE button tapped")
            }
            Spacer()
            ToolbarButton(title: "Console", icon: "terminal") {
                openConsoleInDirectory("~")
            }
            ToolbarButton(title: "Settings", icon: "opticid") {
                print("Settings button tapped")
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

