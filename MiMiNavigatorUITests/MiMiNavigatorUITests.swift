//
//  MiMiNavigatorUITests.swift
//  MiMiNavigatorUITests
//
//  Created by Iakov Senatov on 06.08.24.
//

import XCTest

final class MiMiNavigatorUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


// MARK: --
    func testExample() throws {
        print("Executing testExample") // Log for method tracking
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }


// MARK: --
    func testLaunchPerformance() throws {
        print("Executing testLaunchPerformance") // Log for method tracking
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
