//
//  MiMiNavigatorTests.swift
//  MiMiNavigatorTests
//
//  Created by Iakov Senatov on 06.08.24.
//

import XCTest

@testable import MiMiNavigator

final class MiMiNavigatorTests: XCTestCase {
    private let cloudLinkAliasCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

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

    // MARK: - Cloud Link Alias

    func testCloudLinkAliasesAreLongRandomAndURLSafe() {
        let aliases = (0..<1_000).map { _ in CloudLinkShortener.makeAlias() }
        XCTAssertEqual(Set(aliases).count, aliases.count)
        for alias in aliases {
            XCTAssertTrue(alias.hasPrefix("mimiNavi_"))
            XCTAssertEqual(alias.count, 23)
            let suffix = String(alias.dropFirst("mimiNavi_".count))
            XCTAssertTrue(suffix.allSatisfy(cloudLinkAliasCharacters.contains))
        }
    }
}
