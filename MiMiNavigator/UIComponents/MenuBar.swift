
import SwiftUI

struct MenuBar: View {
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: {
                log.debug("View selected")
            }) {
                Label("F3 View", systemImage: "eye.circle")
                    .labelStyle(.titleAndIcon)
            }
            
            Button(action: {
                log.debug("Edit selected")
            }) {
                Label("F4 Edit", systemImage: "pencil.circle")
                    .labelStyle(.titleAndIcon)
            }
            
            Button(action: {
                log.debug("Copy selected")
            }) {
                Label("F5 Copy", systemImage: "doc.on.doc")
                    .labelStyle(.titleAndIcon)
            }
            
            Button(action: {
                log.debug("Move selected")
            }) {
                Label("F6 Move", systemImage: "arrowshape.turn.up.forward")
                    .labelStyle(.titleAndIcon)
            }
            
            Button(action: {
                log.debug("Delete selected")
            }) {
                Label("F8 Delete", systemImage: "trash.circle")
                    .labelStyle(.titleAndIcon)
            }
            
            Button(action: {
                log.debug("Search selected")
            }) {
                Label("Alt+F7 Search", systemImage: "magnifyingglass.circle")
                    .labelStyle(.titleAndIcon)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
