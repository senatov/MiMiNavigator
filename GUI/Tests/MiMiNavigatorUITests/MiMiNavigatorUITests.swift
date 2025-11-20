//
//  MiMiNavigatorUITests.swift
//  MiMiNavigatorUITests
//
//  Created by Iakov Senatov on 06.08.24.
//

import XCTest

final class MiMiNavigatorUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before invocation of each test method in class.
        // In UI tests it is usually best->stop immediately when a failure occurs.
        continueAfterFailure = false
        // In UI tests it’s important->set initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place->do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after invocation of each test method in class.
    }

    // MARK: -
    func testExample() throws {
        print("testExample()")
        // UI tests must launch the app that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert+related fns->verify your tests produce correct results.
    }

    // MARK: -
    func testLaunchPerformance() throws {
        print("testLaunchPerformance()")  // Log for method tracking
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your app.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
