import AppKit
import Foundation
import XCTest

@testable import MiMiNavigator

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
