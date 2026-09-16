//
//  MiMiNavigatorTests.swift
//  MiMiNavigatorTests
//
//  Created by Iakov Senatov on 06.08.24.
//

import XCTest

@testable import MiMiNavigator

final class MiMiNavigatorTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before invocation of each test method in class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after invocation of each test method in class.
    }

    // MARK: -
    func testExample() throws {
        log.info("testExample()")
        // This is an example of a fnal test case.
        // Use XCTAssert+related fns->verify your tests produce correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws->produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async->allow awaiting for asynchronous code->complete. Check resultsw/assertions afterwards.
    }

    // MARK: -
    func testPerformanceExample() throws {
        log.info("testPerformanceExample()")
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

    // MARK: - Column Auto Fit

    func testKindWidthIncludesRenderedPaddingAndTextReserve() {
        let padding = ColumnID.kind.contentPadding.leading + ColumnID.kind.contentPadding.trailing
        XCTAssertEqual(
            ColumnAutoFitMeasurer.renderedContentInsetWidth(for: .kind),
            padding + ColumnAutoFitMetrics.textRenderingReserve
        )
        XCTAssertGreaterThanOrEqual(
            ColumnAutoFitMeasurer.minimumAutoFitWidth(for: .kind),
            ColumnID.kind.minHeaderWidth
        )
    }

    // MARK: - Cloud Link Alias

    func testCloudLinkAliasesUseThreeShortLatinWords() {
        let latinLetters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        let aliasLetters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        XCTAssertEqual(CloudLinkAliasWords.standard.count, 1_295)
        XCTAssertEqual(CloudLinkAliasWords.compact.count, 82)
        for _ in 0..<1_000 {
            let words = CloudLinkShortener.makeAliasWords()
            XCTAssertTrue((1..<6).contains(words.first.count))
            XCTAssertTrue((1..<6).contains(words.second.count))
            XCTAssertTrue((1..<4).contains(words.third.count))
            XCTAssertTrue([words.first, words.second, words.third].allSatisfy {
                $0.unicodeScalars.allSatisfy(latinLetters.contains)
            })
            let alias = CloudLinkShortener.makeAlias()
            XCTAssertTrue(alias.hasPrefix("mimiNavi"))
            XCTAssertTrue(alias.unicodeScalars.allSatisfy(aliasLetters.contains))
        }
    }

    // MARK: - Drag-Drop Target Priority

    func testToParentTargetWinsOverOverlappingDirectoryRow() {
        let parent = URL(fileURLWithPath: "/tmp/archive-parent", isDirectory: true)
        let directory = URL(fileURLWithPath: "/tmp/archive-temp/first-row", isDirectory: true)
        XCTAssertEqual(
            DragDropTargetResolver.preferredExplicitTarget(parent: parent, directory: directory),
            parent
        )
    }

    func testDirectoryTargetIsUsedWithoutToParentContact() {
        let directory = URL(fileURLWithPath: "/tmp/target-directory", isDirectory: true)
        XCTAssertEqual(
            DragDropTargetResolver.preferredExplicitTarget(parent: nil, directory: directory),
            directory
        )
    }

    func testRegisteredParentTargetSurvivesReleaseHitTestMiss() {
        let archiveParent = URL(fileURLWithPath: "/Users/senat/Downloads", isDirectory: true)
        let archiveTempRoot = URL(fileURLWithPath: "/private/var/folders/archive-temp", isDirectory: true)
        XCTAssertEqual(
            DragDropTargetResolver.releaseTarget(
                registeredParent: archiveParent,
                liveTarget: archiveTempRoot
            ),
            archiveParent
        )
    }

    func testLiveTargetIsUsedWithoutRegisteredParentContact() {
        let directory = URL(fileURLWithPath: "/Users/senat/Documents", isDirectory: true)
        XCTAssertEqual(
            DragDropTargetResolver.releaseTarget(registeredParent: nil, liveTarget: directory),
            directory
        )
    }

    func testArchiveIconFamiliesAndEncryptedOverride() {
        XCTAssertEqual(SmartIconService.archiveIconAssetName(for: "zip", isEncrypted: false), "ArchiveZip")
        XCTAssertEqual(SmartIconService.archiveIconAssetName(for: "rar", isEncrypted: false), "ArchiveClamp")
        XCTAssertEqual(SmartIconService.archiveIconAssetName(for: "pkg", isEncrypted: false), "ArchiveSystem")
        XCTAssertEqual(SmartIconService.archiveIconAssetName(for: "zip", isEncrypted: true), "ArchiveEncrypted")
        XCTAssertEqual(SmartIconService.archiveIconAssetName(for: "rar", isEncrypted: true), "ArchiveEncrypted")
    }

    func testSystemIconNormalizerFillsRetinaCanvasWithoutDistortion() {
        let square = SystemIconNormalizer.fittedDestinationRect(for: CGRect(x: 20, y: 20, width: 16, height: 16))
        XCTAssertEqual(square.width, 58, accuracy: 1)
        XCTAssertEqual(square.height, 58, accuracy: 1)
        let wide = SystemIconNormalizer.fittedDestinationRect(for: CGRect(x: 20, y: 20, width: 16, height: 8))
        XCTAssertEqual(wide.width, 58, accuracy: 1)
        XCTAssertEqual(wide.height, 29, accuracy: 1)
    }

    func testLocalParentStripResolvesParentDirectory() {
        let current = URL(fileURLWithPath: "/Users/senat/Downloads/Umsaetze_08_2026", isDirectory: true)
        XCTAssertEqual(
            DragDropTargetResolver.parentDestination(currentURL: current),
            URL(fileURLWithPath: "/Users/senat/Downloads", isDirectory: true)
        )
    }

    func testFilesystemRootHasNoParentDropDestination() {
        XCTAssertNil(
            DragDropTargetResolver.parentDestination(
                currentURL: URL(fileURLWithPath: "/", isDirectory: true)
            )
        )
    }
}
