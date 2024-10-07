//
//  ContentView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//
import SwiftUI

struct File: Identifiable {
    let id = UUID()
    let name: String
}

struct TotalCommanderResizableView: View {
    @State private var leftPanelWidth: CGFloat = 0 // Set dynamically in body
    
        // Example files for both panels
    let leftFiles = [File(name: "File1.txt"), File(name: "Folder1"),
                     File(name: "Image.png")]
    let rightFiles = [File(name: "Doc1.docx"), File(name: "Backup.zip")]
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                    // Toolbar at the top
                HStack {
                    Button("Copy") { /* Copy action */ }
                    Button("Move") { /* Move action */ }
                    Button("Delete") { /* Delete action */ }
                    Spacer()
                    Button("Settings") { /* Open settings */ }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                
                HStack(spacing: 0) {
                        // Left panel
                    VStack {
                        List(leftFiles) { file in
                            Text(file.name)
                                .contextMenu {
                                    Button(action: {
                                            // Copy action
                                    }) {
                                        Text("Copy")
                                        Image(systemName: "doc.on.doc")
                                    }
                                    Button(action: {
                                            // Rename action
                                    }) {
                                        Text("Rename")
                                        Image(systemName: "pencil")
                                    }
                                    Button(action: {
                                            // Delete action
                                    }) {
                                        Text("Delete")
                                        Image(systemName: "trash")
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
                        List(rightFiles) { file in
                            Text(file.name)
                                .contextMenu {
                                    Button(action: {
                                            // Copy action
                                    }) {
                                        Text("Copy")
                                        Image(systemName: "doc.on.doc")
                                    }
                                    Button(action: {
                                            // Rename action
                                    }) {
                                        Text("Rename")
                                        Image(systemName: "pencil")
                                    }
                                    Button(action: {
                                            // Delete action
                                    }) {
                                        Text("Delete")
                                        Image(systemName: "trash")
                                    }
                                }
                        }
                        .listStyle(PlainListStyle())
                        .border(Color.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                    // Set the initial left panel width if it was not restored
                leftPanelWidth = UserDefaults.standard.object(forKey: "leftPanelWidth") as? CGFloat ?? geometry.size.width / 2
            }
        }
    }
}

struct TotalCommanderResizableView_Previews: PreviewProvider {
    static var previews: some View {
        TotalCommanderResizableView()
    }
}
