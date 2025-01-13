    //
    //  TopMenuBarView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.10.24.
    //

import SwiftUI

struct TopMenuBarView: View {
    @Binding var isShowMenu: Bool

    var toggleMenu: () -> Void

    var body: some View {
        HStack {
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

            Menu {
                Button("Change Attributes", action: {})
                Button("Pack...", action: {})
                Button("Unpack Specific Files...", action: {})
                Button("Test Archive(s)", action: {})
                Button("Compare By Content", action: {})
                Button("Associate With...", action: {})
                Button("Internal Associations (MimiNav only)...", action: {})
                Button("Properties...", action: {})
                Button("Calculate Occupied Space...", action: {})
                Button("Multi Rename Tool...", action: {})
                Button("Edit Comme&nt...", action: {})
                Button("Print", action: {})
                Button("Split File...", action: {})
                Button("Combine Files...", action: {})
                Button("Encode File(MIME,UUE,XXE)...", action: {})
                Button("Decode File(MIME,UUE,XXE,BinHex)...", action: {})
                Button("Create Checksum...", action: {})
                Button("Veruify Checksum...", action: {})
                Button("Quit...", action: {})
            } label: {
                Label("Files", systemImage: "externaldrive.connected.to.line.below")
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding()

            Menu {
                Button("Select Group...", action: {})
                Button("Unselect Group...", action: {})
                Button("Select &All", action: {})
                Button("Unselect All", action: {})
                Button("Invert Selection...", action: {})
                Button("Select All With Same Extension", action: {})
                Button("Save Selection", action: {})
                Button("Restore Selection", action: {})
                Button("Save Selection to File", action: {})
                Button("Load Selection from File", action: {})
                Button("Copy Selected Names To Clipboard", action: {})
                Button("Copy Names With Path To Clipboard...", action: {})
                Button("Copy To Clipboard With All Details...", action: {})
                Button("Copy To Clipboard With All Path+Details...", action: {})
            } label: {
                Label("Mark", systemImage: "pencil.circle")
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding()

            MenuButton(label: "Commands", systemImage: "doc.on.doc")
            MenuButton(label: "Net", systemImage: "network")
            MenuButton(label: "Show", systemImage: "dot.circle.viewfinder")
            MenuButton(label: "Configuration", systemImage: "gear.circle")
            MenuButton(label: "Start", systemImage: "figure.run.circle")
            MenuButton(label: "Help", systemImage: "questionmark.circle")
        }
        .padding(.leading, 0.2)
        .padding(.bottom, 0.1)
    }
}
