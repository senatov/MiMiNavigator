import SwiftUI
import FindFilesKit
import FileModelKit

// MARK: - Result Overflow Indicator
struct FindFilesResultOverflow: View {
    let result: FindFilesResult
    let text: String
    let selected: Bool
    let isName: Bool
    var body: some View {
        FileInfoButton(
            file: CustomFile(name: result.fileName, path: result.filePath),
            isSelected: selected,
            displayedText: text,
            fullText: isName ? result.fileName + "\n" + result.filePath : text,
            textFont: isName ? .systemFont(ofSize: 14, weight: .light) : .systemFont(ofSize: 12)
        )
    }
}
