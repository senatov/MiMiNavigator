import SwiftUI

    /// Main view representing a Total Commander-like interface with resizable panels and a vertical tree menu.
    ///
    /// Features:
    /// - Vertical menu in the form of a tree structure to navigate files and folders.
    /// - Button to show/hide the vertical menu.
    /// - Left and right panels to display file lists, with a draggable divider to resize them.
    /// - Bottom toolbar with actions like Copy, Move, Delete, and Settings.
struct TotalCommanderResizableView: View {
    @State private var leftPanelWidth: CGFloat = 0 // Set dynamically in body
    @State private var showMenu: Bool = false // State to show/hide menu
    @State private var selectedFile: File? = nil // Track the selected file
    
        // Example files for both panels
    let leftFiles = [File(name: "File1.txt"), File(name: "Folder1"),
                     File(name: "Image.png")]
    let rightFiles = [File(name: "Doc1.docx"), File(name: "Backup.zip")]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                    // Button to open vertical tree menu
                HStack {
                    Button(action: {
                        withAnimation {
                            showMenu.toggle()
                        }
                    }) {
                        Text("Menu")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                
                HStack(spacing: 0) {
                        // Vertical tree menu
                    if showMenu {
                        TreeView(files: leftFiles, selectedFile: $selectedFile)
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.gray.opacity(0.1))
                    }
                    
                        // Left panel
                    VStack {
                        List(leftFiles, id: \.id) { file in
                            Text(file.name)
                                .contextMenu {
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
                        .listStyle(PlainListStyle())
                        .frame(width: leftPanelWidth == 0 ? geometry.size.width / 2 : leftPanelWidth)
                        .border(Color.gray)
                    }
                    
                        // Divider
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 5)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newWidth = leftPanelWidth + value.translation.width
                                    if newWidth > 100 && newWidth < geometry.size.width - 100 {
                                        leftPanelWidth = newWidth
                                    }
                                }
                                .onEnded { _ in
                                    UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
                                }
                        )
                    
                        // Right panel
                    VStack {
                        List(rightFiles, id: \.id) { file in
                            Text(file.name)
                                .contextMenu {
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
                        .listStyle(PlainListStyle())
                        .border(Color.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                    // Toolbar at the bottom
                HStack {
                    Button(action: { /* Copy action */ }) {
                        Text("Copy")
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: { /* Move action */ }) {
                        Text("Move")
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: { /* Delete action */ }) {
                        Text("Delete")
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                    Button(action: { /* Settings action */ }) {
                        Text("Settings")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color.gray.opacity(0.2))
            }
            .onAppear {
                    // Set the initial left panel width if it was not restored
                leftPanelWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
            }
        }
    }
}