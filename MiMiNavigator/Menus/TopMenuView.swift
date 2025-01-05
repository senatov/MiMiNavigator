import SwiftUI

struct TopMenuView: View {
    var body: some View {
        VStack {
            // Верхняя панель
            HStack {
                HStack {
                    MenuButton(label: "Files", systemImage: "eye.circle")
                    MenuButton(label: "Mark", systemImage: "pencil.circle")
                    MenuButton(label: "Commands", systemImage: "doc.on.doc")
                    MenuButton(label: "Net", systemImage: "arrowshape.turn.up.forward")
                    MenuButton(label: "Show", systemImage: "trash.circle")
                    MenuButton(label: "Configuration", systemImage: "magnifyingglass.circle")
                    MenuButton(label: "Start", systemImage: "arrowshape.turn.up.forward")
                    MenuButton(label: "Help", systemImage: "arrowshape.turn.up.forward")
                }
                .padding(.horizontal)
                .background(Color.gray.opacity(0.2))  // Background for visibility
                .cornerRadius(8)
            }
            .padding()
            .background(Color.gray.opacity(0.1))  // Header background
            Spacer()
            // Основной контент
            Text("Main application content goes here")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            Spacer()
            // Нижнее меню
            UnderMenuView()
        }
        .background(Color.gray.opacity(0.05))
        .edgesIgnoringSafeArea(.bottom)
    }
}
