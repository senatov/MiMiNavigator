//
//  MiMiNavigatorUITestsLaunchTests.swift
//  MiMiNavigatorUITests
//
//  Created by Iakov Senatov on 06.08.24.
//

import XCTest

final class MiMiNavigatorUITestsLaunchTests: XCTestCase {

    // MARK: -
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    // MARK: -
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: --
    func testLaunch() throws {
        print("Executing testLaunch")  // Log for method tracking
        let app = XCUIApplication()
        app.launch()
        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
