import FileModelKit
import Foundation

// MARK: - Panel State
/// Encapsulates all state belonging to a single file panel.
struct PanelState {

    /// Current directory displayed in panel
    var currentDirectory: URL

    /// Files currently displayed
    var displayedFiles: [CustomFile] = []

    /// Currently selected file
    var selectedFile: CustomFile?

    /// Navigation history for this panel
    var navigationHistory: NavigationHistory
}
