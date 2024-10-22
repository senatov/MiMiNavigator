import SwiftUI

    /// Represents a file or folder that can optionally have child items to form a tree structure.
struct CustomFile: Identifiable {
    let id = UUID()
    let name: String
    var children: [CustomFile]? // Optional children to create tree structure
}

    /// Main view representing a Total Commander-like interface with resizable panels and a vertical tree menu.
    ///
    /// Features:
    /// - Vertical menu in the form of a tree structure to navigate files and folders.
    /// - Button to show/hide the vertical tree menu.
    /// - Left and right panels to display file lists, with a draggable divider to resize them.
    /// - Bottom toolbar with actions like Copy, Move, Delete, and Settings.
struct TotalCommanderResizableView: View {
    @State private var leftPanelWidth: CGFloat = 0 // Set dynamically in body
    @State private var showMenu: Bool = false // State to show/hide menu
    @State private var selectedFile: CustomFile? = nil // Track the selected file
    @State private var showTooltip: Bool = false // State to show/hide the tooltip
    @State private var tooltipPosition: CGPoint = .zero // Position of the tooltip
    @State private var tooltipText: String = "" // Text of the tooltip
    
        // Example files for both panels
    let leftFiles = [
        CustomFile(name: "File1.txt", children: nil),
        CustomFile(name: "Folder1", children: [
            CustomFile(name: "SubFile1.txt", children: nil),
            CustomFile(name: "SubFile2.txt", children: nil)
        ]),
        CustomFile(name: "Image.png", children: nil)
    ]
    let rightFiles = [
        CustomFile(name: "Doc1.docx", children: nil),
        CustomFile(name: "Backup.zip", children: nil)
    ]
    
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
        leftPanelWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
    }
    
        /// Builds the button to open the vertical tree menu
    private func buildMenuButton() -> some View {
        HStack {
            Button(action: {
                withAnimation {
                    showMenu.toggle()
                }
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
    
        /// Builds the vertical tree menu
    private func buildVerticalTreeMenu() -> some View {
        TreeView(files: leftFiles, selectedFile: $selectedFile)
            .padding()
            .frame(maxWidth: 200)
            .background(Color.gray.opacity(0.1))
    }
    
        /// Builds the left panel containing a list of files
    private func buildLeftPanel(geometry: GeometryProxy) -> some View {
        VStack {
            List(leftFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        buildContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .frame(width: leftPanelWidth == 0 ? geometry.size.width / 2 : leftPanelWidth)
            .border(Color.gray)
        }
    }
    
        /// Builds the right panel containing a list of files
    private func buildRightPanel() -> some View {
        VStack {
            List(rightFiles, id: \.id) { file in
                Text(file.name)
                    .contextMenu {
                        buildContextMenu()
                    }
            }
            .listStyle(PlainListStyle())
            .border(Color.gray)
        }
    }
    
    /// Builds the draggable divider between the panels
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
    
        /// Handles the drag gesture for the divider
    private func handleDividerDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let newWidth = leftPanelWidth + value.translation.width
        if newWidth > 100 && newWidth < geometry.size.width - 100 {
            leftPanelWidth = newWidth
            let (tooltipText, tooltipPosition) = TooltipModule.calculateTooltip(location: value.location, dividerX: newWidth, totalWidth: geometry.size.width)
            self.tooltipText = tooltipText
            self.tooltipPosition = tooltipPosition
            showTooltip = true
        }
    }
    
        /// Builds the bottom toolbar with various actions
    private func buildToolbar() -> some View {
        HStack {
            buildToolbarButton(title: "Copy", action: { /* Copy action */ })
            buildToolbarButton(title: "Move", action: { /* Move action */ })
            buildToolbarButton(title: "Delete", action: { /* Delete action */ })
            Spacer()
            buildToolbarButton(title: "Settings", action: { /* Settings action */ })
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
    
        /// Builds a toolbar button
    private func buildToolbarButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleDoubleClickDivider(geometry: GeometryProxy) {
        leftPanelWidth = geometry.size.width / 2
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }
    
        /// Builds the context menu for file actions
    private func buildContextMenu() -> some View {
        Group {
            Button {
                    // Copy action
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                    // Rename action
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                    // Delete action
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
