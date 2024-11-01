
import Foundation

// Actor for managing file arrays shared across the app safely in a concurrent environment
actor FileManagerState {
    static let shared = FileManagerState()
    
    private var leftFiles: [CustomFile] = []
    private var rightFiles: [CustomFile] = []
    
    // Methods for accessing and mutating leftFiles
    func getLeftFiles() -> [CustomFile] {
        return leftFiles
    }
    
    func setLeftFiles(_ newFiles: [CustomFile]) {
        leftFiles = newFiles
    }
    
    // Methods for accessing and mutating rightFiles
    func getRightFiles() -> [CustomFile] {
        return rightFiles
    }
    
    func setRightFiles(_ newFiles: [CustomFile]) {
        rightFiles = newFiles
    }
}
