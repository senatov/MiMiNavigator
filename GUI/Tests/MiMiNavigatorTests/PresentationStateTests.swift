import AppKit
import Foundation
import XCTest

@testable import MiMiNavigator

// MARK: - Presentation State Tests
@MainActor
final class PresentationStateTests: XCTestCase {
    // MARK: - Menu Bar Recovery
    func testMenuBarRepairDetectsMissingImageAndZeroSizedWindow() {
        let screen = NSRect(x: 0, y: 0, width: 3840, height: 1600)
        let validItem = NSRect(x: 3400, y: 1570, width: 50, height: 30)
        XCTAssertTrue(MenuBarController.statusItemNeedsRepair(isVisible: true, hasImage: false, windowFrame: validItem, screenFrames: [screen]))
        XCTAssertTrue(MenuBarController.statusItemNeedsRepair(isVisible: true, hasImage: true, windowFrame: .zero, screenFrames: [screen]))
        XCTAssertTrue(MenuBarController.statusItemNeedsRepair(isVisible: false, hasImage: true, windowFrame: validItem, screenFrames: [screen]))
        XCTAssertFalse(MenuBarController.statusItemNeedsRepair(isVisible: true, hasImage: true, windowFrame: validItem, screenFrames: [screen]))
    }

    func testMenuBarRepairDetectsOffScreenWindow() {
        let screen = NSRect(x: 0, y: 0, width: 3840, height: 1600)
        let offScreenItem = NSRect(x: 0, y: -15, width: 50, height: 30)
        XCTAssertTrue(MenuBarController.statusItemNeedsRepair(isVisible: true, hasImage: true, windowFrame: offScreenItem, screenFrames: [screen]))
    }

    // MARK: - Window Policy
    func testStandaloneWindowPolicyUsesNormalNonFloatingPanel() {
        let panel = NSPanel()
        WindowPresentationPolicy.apply(.standalone, to: panel)
        XCTAssertFalse(panel.isFloatingPanel)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertEqual(panel.level, .normal)
        XCTAssertTrue(WindowPresentationPolicy.isStandalone(panel))
    }

    func testModalDecisionPolicyHidesOutsideActiveApplication() {
        let panel = NSPanel()
        WindowPresentationPolicy.apply(.modalDecision, to: panel)
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertTrue(panel.hidesOnDeactivate)
        XCTAssertEqual(panel.level, .modalPanel)
        XCTAssertFalse(WindowPresentationPolicy.isStandalone(panel))
    }

    // MARK: - Find Files Criteria
    func testRepeatedSearchConfigurationUsesNewPanelDirectory() {
        let viewModel = FindFilesViewModel()
        viewModel.searchDirectory = "/old/location"
        viewModel.advancedSettings.searchDirectory = "/old/advanced"
        viewModel.configure(searchPath: "/new/location")
        XCTAssertEqual(viewModel.searchDirectory, "/new/location")
        XCTAssertEqual(viewModel.advancedSettings.searchDirectory, "/new/location")
    }

    // MARK: - Window Replacement
    func testReplacementReleasesHiddenWindowContentAndDelegate() {
        let panel = NSPanel()
        panel.isReleasedWhenClosed = false
        let delegate = ReplacementTestDelegate()
        panel.delegate = delegate
        panel.contentView = NSView()
        panel.orderOut(nil)
        WindowReplacement.close(panel)
        XCTAssertNil(panel.contentView)
        XCTAssertNil(panel.delegate)
        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(delegate.didClose)
    }

    func testContentSearchNormalizesFolderOnlyFilter() {
        let viewModel = FindFilesViewModel()
        viewModel.activeModule = .advanced
        viewModel.advancedSettings.searchText = "invoice"
        viewModel.advancedSettings.itemTypeFilter = .foldersOnly
        viewModel.advancedSettings.emptyFoldersOnly = true
        viewModel.normalizeContentSearchSettings()
        XCTAssertEqual(viewModel.advancedSettings.itemTypeFilter, .filesOnly)
        XCTAssertFalse(viewModel.advancedSettings.emptyFoldersOnly)
    }

    func testResetAdvancedFiltersPreservesPrimaryCriteria() {
        let viewModel = FindFilesViewModel()
        viewModel.advancedSettings.fileNamePattern = "*.pdf"
        viewModel.advancedSettings.searchText = "invoice"
        viewModel.advancedSettings.searchDirectory = "/tmp"
        viewModel.advancedSettings.itemTypeFilter = .filesOnly
        viewModel.advancedSettings.useSizeFilter = true
        viewModel.advancedSettings.useStaleItemFilter = true
        viewModel.resetAdvancedFilters()
        XCTAssertEqual(viewModel.advancedSettings.fileNamePattern, "*.pdf")
        XCTAssertEqual(viewModel.advancedSettings.searchText, "invoice")
        XCTAssertEqual(viewModel.advancedSettings.searchDirectory, "/tmp")
        XCTAssertEqual(viewModel.advancedSettings.itemTypeFilter, .filesAndFolders)
        XCTAssertFalse(viewModel.advancedSettings.useSizeFilter)
        XCTAssertFalse(viewModel.advancedSettings.useStaleItemFilter)
    }

    // MARK: - Media Conversion Phase
    func testMediaConversionActivePhases() {
        XCTAssertTrue(MediaConversionPhase.preparing.isActive)
        XCTAssertTrue(MediaConversionPhase.running(tool: "ffmpeg").isActive)
        XCTAssertTrue(MediaConversionPhase.awaitingDecision(reason: "size").isActive)
        XCTAssertFalse(MediaConversionPhase.cancelled.isActive)
        XCTAssertFalse(MediaConversionPhase.completed(output: URL(fileURLWithPath: "/tmp/out.gif")).isActive)
    }

    // MARK: - File Operation Notices

    func testFileOperationNoticeDurationsAreOneAndAHalfTimesShorter() {
        XCTAssertEqual(FileOperationOutcomePresenter.toastDisplayDuration, .milliseconds(1_600))
        XCTAssertEqual(FileOperationOutcomePresenter.bannerDisplayDuration, .milliseconds(5_333))
    }
}

// MARK: - Media process diagnostics tests
@MainActor
final class MediaProcessDiagnosticsTests: XCTestCase {
    // MARK: - GIF recovery
    func testGIFRecoveryRestoresBackupAndPreservesConflicts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let backup = directory.appendingPathComponent("backup.gif")
        let target = directory.appendingPathComponent("target.gif")
        let original = Data("original".utf8)
        try original.write(to: backup)
        MediaConversionService.restoreGIFBackup(backup, target: target)
        XCTAssertEqual(try Data(contentsOf: target), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
        let preserved = Data("preserved-backup".utf8)
        try preserved.write(to: backup)
        MediaConversionService.restoreGIFBackup(backup, target: target)
        XCTAssertEqual(try Data(contentsOf: target), original)
        XCTAssertEqual(try Data(contentsOf: backup), preserved)
    }

    // MARK: - Destination aliases
    func testRejectsOriginalSymlinkAndHardLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.gif")
        try Data("source".utf8).write(to: source)
        let symbolic = directory.appendingPathComponent("symbolic.gif")
        let hard = directory.appendingPathComponent("hard.gif")
        try FileManager.default.createSymbolicLink(at: symbolic, withDestinationURL: source)
        try FileManager.default.linkItem(at: source, to: hard)
        for target in [source, symbolic, hard] {
            XCTAssertThrowsError(try MediaConversionService.validateDestination(source: source, target: target))
        }
        XCTAssertNoThrow(try MediaConversionService.validateDestination(source: source, target: directory.appendingPathComponent("new.gif")))
        XCTAssertEqual(try Data(contentsOf: source), Data("source".utf8))
    }

    // MARK: - Final output and failure context
    func testCapturesFinalStderrOnFailure() async {
        do {
            try await MediaConversionService.shared.runProcess(executablePath: "/bin/zsh", arguments: ["-c", "print -nu2 'diagnostic-tail'; exit 7"], panel: .shared)
            XCTFail("Expected exit failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("diagnostic-tail"))
            XCTAssertTrue(error.localizedDescription.contains("7"))
        }
    }

    // MARK: - Output draining
    func testDrainsLargeOutputWithBoundedTail() async throws {
        let output = try await MediaConversionService.shared.runProcess(executablePath: "/bin/zsh", arguments: ["-c", "repeat 10000 print -n 'abcdefghij'; print -n 'FINAL'"], panel: .shared)
        XCTAssertEqual(output.utf8.count, 32 * 1024)
        XCTAssertTrue(output.hasSuffix("FINAL"))
    }

    // MARK: - File redirection
    func testRedirectsOutputWithoutPipeWait() async throws {
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: target) }
        try await MediaConversionService.shared.runProcess(executablePath: "/bin/zsh", arguments: ["-c", "print -n 'file-output'"], panel: .shared, outputFile: target)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "file-output")
    }
}

// MARK: - Replacement Test Delegate
@MainActor
private final class ReplacementTestDelegate: NSObject, NSWindowDelegate {
    var didClose = false
    func windowWillClose(_ notification: Notification) {
        didClose = true
    }
}
