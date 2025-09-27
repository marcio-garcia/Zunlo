//
//  ZunloUITests.swift
//  ZunloUITests
//
//  Created by Marcio Garcia on 6/22/25.
//

import XCTest

final class ZunloUITests: XCTestCase {
    var app: XCUIApplication!

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testSimpleScreenshot() throws {
        // Simple test that just captures the main screen
        sleep(3)
        snapshot("01-today-view")
    }

    @MainActor
    func testGenerateScreenshots() throws {
        // Wait for app to load completely
        sleep(3)

        // 1. Today View (Main screen) - Always capture this first
        snapshot("01-today-view")

        // For debugging: print all available buttons
        print("Available buttons:")
        for button in app.buttons.allElementsBoundByIndex {
            if button.exists {
                print("Button: \(button.identifier) - \(button.label)")
            }
        }

        // 2. Settings Screen - Try different selectors
        var settingsButton = app.buttons["slider.horizontal.3"]
        if !settingsButton.exists {
            // Try finding by accessibility label or other identifiers
            settingsButton = app.buttons.matching(identifier: "slider.horizontal.3").firstMatch
        }

        if settingsButton.exists && settingsButton.isHittable {
            settingsButton.tap()
            sleep(2)
            snapshot("02-settings")

            // Go back - try different methods
            if app.navigationBars.buttons.count > 0 {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            } else if app.buttons["Back"].exists {
                app.buttons["Back"].tap()
            } else {
                // Swipe back gesture
                app.swipeRight()
            }
            sleep(1)
        }

        // 3. Add Task Sheet
        let addTaskButton = app.buttons["note.text.badge.plus"]
        if addTaskButton.exists && addTaskButton.isHittable {
            addTaskButton.tap()
            sleep(2)
            snapshot("03-add-task")

            // Try multiple dismiss methods
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            } else if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else {
                // Swipe down to dismiss
                app.swipeDown()
            }
            sleep(1)
        }

        // 4. Add Event Sheet
        let addEventButton = app.buttons["calendar.badge.plus"]
        if addEventButton.exists && addEventButton.isHittable {
            addEventButton.tap()
            sleep(2)
            snapshot("04-add-event")

            // Dismiss sheet
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            } else if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else {
                app.swipeDown()
            }
            sleep(1)
        }

        // 5. Chat Interface
        let chatButton = app.buttons["bubble.left.and.bubble.right.fill"]
        if chatButton.exists && chatButton.isHittable {
            chatButton.tap()
            sleep(3)
            snapshot("05-chat-interface")
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
