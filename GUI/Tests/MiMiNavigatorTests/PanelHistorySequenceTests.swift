import XCTest
@testable import MiMiNavigator

// MARK: - Panel History Sequence Tests
@MainActor
final class PanelHistorySequenceTests: XCTestCase {
    // MARK: - Chronological Back and Forward
    func testHistoryPreservesRepeatedVisitsAndForwardPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let first = root.appendingPathComponent("first", isDirectory: true)
        let second = root.appendingPathComponent("second", isDirectory: true)
        let third = root.appendingPathComponent("third", isDirectory: true)
        for directory in [first, second, third] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let storageKey = "PanelNavigationHistory.sequence.\(UUID().uuidString)"
        defer { MiMiDefaults.shared.removeObject(forKey: storageKey) }
        let history = PanelNavigationHistory(panel: .left, storageKey: storageKey)
        for directory in [first, second, first, third] { history.navigateTo(directory) }
        XCTAssertEqual(history.goBack(), first)
        XCTAssertEqual(history.goBack(), second)
        XCTAssertEqual(history.goBack(), first)
        XCTAssertFalse(history.canGoBack)
        XCTAssertEqual(history.goForward(), second)
        history.navigateTo(second)
        XCTAssertEqual(history.goForward(), first)
        history.flush()
        let reloaded = PanelNavigationHistory(panel: .left, storageKey: storageKey)
        XCTAssertEqual(reloaded.currentPath, first)
        XCTAssertEqual(reloaded.goBack(), second)
    }
}
