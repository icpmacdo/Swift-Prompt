//
//  Swift-PromptUITestsLaunchTests.swift
//  Swift-PromptUITests
//
//  Created by Ian MacDonald on 2025-02-01.
//

import XCTest

final class SwiftPromptUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Default screenshot of app launch

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
