import AppKit
import Foundation
import FindFilesKit
import XCTest

@testable import MiMiNavigator

// MARK: - Remote Server URL Parser Tests
final class RemoteServerURLParserTests: XCTestCase {
    // MARK: - Incomplete Scheme Input
    func testIncompleteSchemeInputDoesNotParseOrCrash() {
        for input in ["sftp:", "sftp:/", "sftp://"] {
            XCTAssertNil(RemoteServerURLParser.parse(input))
        }
    }

    // MARK: - Complete SFTP URL
    func testCompleteSFTPURLParsesAllTypedFields() {
        let parsed = RemoteServerURLParser.parse("sftp://senatov@192.168.178.59")
        XCTAssertEqual(parsed?.proto, .sftp)
        XCTAssertEqual(parsed?.host, "192.168.178.59")
        XCTAssertEqual(parsed?.user, "senatov")
        XCTAssertNil(parsed?.port)
    }
}

// MARK: - Presentation State Tests
@MainActor
final class PresentationStateTests: XCTestCase {
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

// MARK: - Editable Search Template Tests
@MainActor
final class FindFilesTemplateTests: XCTestCase {
    // MARK: - Shared Directory Scope
    func testSearchDirectoryIsSharedByBothModules() {
        let viewModel = FindFilesViewModel()
        viewModel.searchDirectory = "/tmp"
        viewModel.activeModule = .general
        XCTAssertEqual(viewModel.activeSearchSettings.searchDirectory, "/tmp")
        viewModel.activeModule = .advanced
        XCTAssertEqual(viewModel.activeSearchSettings.searchDirectory, "/tmp")
        viewModel.selectAdvancedEditor(templates: true)
        XCTAssertEqual(viewModel.searchDirectory, "/tmp")
        viewModel.searchDirectory = "/Users"
        viewModel.selectAdvancedEditor(templates: false)
        XCTAssertEqual(viewModel.searchDirectory, "/Users")
    }
    // MARK: - Reject File Targets
    func testSearchRejectsFileAsDirectory() {
        let viewModel = FindFilesViewModel()
        viewModel.activeModule = .general
        viewModel.searchDirectory = #filePath
        viewModel.startSearch()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNotEqual(viewModel.searchState, .searching)
        viewModel.configure(searchPath: #filePath)
        XCTAssertEqual(viewModel.searchDirectory, URL(fileURLWithPath: #filePath).deletingLastPathComponent().path)
    }
    // MARK: - Mutually Exclusive Editors
    func testEditorSwitchRestoresIndependentCriteria() {
        let viewModel = FindFilesViewModel()
        viewModel.activeModule = .advanced
        viewModel.advancedSettings = FindFilesSearchSettings()
        viewModel.advancedSettings.fileNamePattern = "*.swift"
        viewModel.advancedSettings.searchDirectory = "/tmp/manual"
        viewModel.selectAdvancedEditor(templates: true)
        XCTAssertTrue(viewModel.usesTemplateEditor)
        XCTAssertEqual(viewModel.activeSearchSettings.activePreset, .largeStaleFiles)
        viewModel.advancedSettings.staleAgeAmount = "3"
        viewModel.selectAdvancedEditor(templates: false)
        XCTAssertFalse(viewModel.usesTemplateEditor)
        XCTAssertEqual(viewModel.activeSearchSettings.fileNamePattern, "*.swift")
        XCTAssertEqual(viewModel.activeSearchSettings.searchDirectory, "/tmp/manual")
        XCTAssertFalse(viewModel.activeSearchSettings.useStaleItemFilter)
        viewModel.selectAdvancedEditor(templates: true)
        XCTAssertEqual(viewModel.activeSearchSettings.staleAgeAmount, "3")
    }
    // MARK: - Content Fitting
    func testResultAutofitKeepsSizeCompactAndUsesAvailableWidth() {
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 1000, height: 300))
        for title in ["Name", "Location", "Size"] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            column.title = title
            column.minWidth = 40
            column.maxWidth = 1000
            table.addTableColumn(column)
        }
        FindFilesResultsColumnFit.apply(to: table, widths: ["Name": 300, "Location": 400, "Size": 80])
        XCTAssertEqual(table.tableColumns[2].width, 80, accuracy: 1)
        XCTAssertGreaterThan(table.tableColumns[1].width, table.tableColumns[0].width)
        XCTAssertLessThanOrEqual(table.tableColumns.reduce(0) { $0 + $1.width }, 1000)
    }

    // MARK: - Independent Leftover Criterion
    func testDisabledLeftoverCriterionSurvivesPersistence() throws {
        let viewModel = FindFilesViewModel()
        viewModel.applyApplicationLeftoversPreset()
        viewModel.advancedSettings.usesApplicationLeftovers = false
        let data = try JSONEncoder().encode(viewModel.advancedSettings)
        let restored = try JSONDecoder().decode(FindFilesSearchSettings.self, from: data)
        XCTAssertEqual(restored.activePreset, .applicationLeftovers)
        XCTAssertFalse(restored.usesApplicationLeftovers)
    }
    // MARK: - Legacy Preferences
    func testLegacyLeftoverPresetRetainsSpecializedSearch() throws {
        var settings = FindFilesSearchSettings()
        settings.activePreset = .applicationLeftovers
        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(FindFilesSearchSettings.self, from: data)
        XCTAssertTrue(restored.usesApplicationLeftovers)
    }
    // MARK: - Editable Directory
    func testDirectoryEditDisablesHiddenLibraryScopeAndPreservesTemplate() {
        let viewModel = FindFilesViewModel()
        viewModel.applyApplicationLeftoversPreset()
        viewModel.advancedSettings.searchDirectory = "/tmp"
        viewModel.markAdvancedCriteriaEdited()
        XCTAssertFalse(viewModel.advancedSettings.usesApplicationLeftovers)
        XCTAssertEqual(viewModel.advancedSettings.activePreset, .applicationLeftovers)
    }
    // MARK: - Disabled Age Criterion
    func testDisabledAgeDoesNotValidateOrApplyStaleValues() {
        let viewModel = FindFilesViewModel()
        viewModel.activeModule = .advanced
        viewModel.applyLargeStaleFilesPreset()
        viewModel.advancedSettings.useStaleItemFilter = false
        viewModel.advancedSettings.staleAgeAmount = "invalid"
        viewModel.errorMessage = nil
        XCTAssertNil(viewModel.staleAgeDaysIfNeeded())
        XCTAssertNil(viewModel.errorMessage)
        var criteria = FindFilesCriteria(searchDirectory: URL(fileURLWithPath: "/tmp"))
        viewModel.applyStaleCriteria(to: &criteria, settings: viewModel.advancedSettings, staleAgeDays: 365)
        XCTAssertNil(criteria.modificationOlderThanDays)
        XCTAssertNil(criteria.accessOlderThanDays)
    }
    // MARK: - Template Transitions
    func testNewTemplatesClearConflictingCriteria() {
        let viewModel = FindFilesViewModel()
        viewModel.applyApplicationLeftoversPreset()
        viewModel.advancedSettings.invertFileNamePattern = true
        viewModel.applyRecentlyModifiedPreset()
        XCTAssertFalse(viewModel.advancedSettings.usesApplicationLeftovers)
        XCTAssertFalse(viewModel.advancedSettings.invertFileNamePattern)
        XCTAssertFalse(viewModel.advancedSettings.useStaleItemFilter)
        XCTAssertFalse(viewModel.advancedSettings.useSizeFilter)
        XCTAssertTrue(viewModel.advancedSettings.useDateFilter)
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: viewModel.advancedSettings.dateFrom, to: viewModel.advancedSettings.dateTo).day, 7)
        viewModel.applyOldDownloadsPreset()
        XCTAssertFalse(viewModel.advancedSettings.useDateFilter)
        XCTAssertTrue(viewModel.advancedSettings.useStaleItemFilter)
        XCTAssertEqual(viewModel.advancedSettings.staleAgeAmount, "6")
        XCTAssertEqual(URL(fileURLWithPath: viewModel.advancedSettings.searchDirectory).lastPathComponent, "Downloads")
    }
}
