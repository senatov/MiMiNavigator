
import SwiftUI

struct PathStatusView: View {
    @Binding var path: String
    @State private var isEditable: Bool = false
    var onCommit: (() -> Void)?

    var body: some View {
        HStack {
            if isEditable {
                TextField("Enter path", text: $path, onCommit: {
                    isEditable = false
                    onCommit?()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(path)
                    .onTapGesture(count: 2) {
                        isEditable = true
                    }
            }
            Spacer()
        }
        .padding(.horizontal)
        .frame(height: 30)
    }
}
