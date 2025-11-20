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
}
