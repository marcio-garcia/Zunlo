//
//  ZunloUITests.swift
//  ZunloUITests
//
//  Created by Marcio Garcia on 6/22/25.
//

import XCTest

@MainActor
final class ZunloUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["FASTLANE_SNAPSHOT"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSimpleScreenshot() throws {
        // Simple test that just captures the main screen
        sleep(5)
        snapshot("01-today-view")
    }

    func testGenerateScreenshots() throws {
        // Wait for app to load completely
        sleep(5)

        // Generate all screenshots
        captureMainScreen()
//        debugPrintButtons()
        captureScreen(buttonLabels: ["Settings", "Ajustes"], snapshotName: "02-settings") {
            app.swipeDown(velocity: XCUIGestureVelocity.fast)
        }
        captureScreen(buttonLabels: ["Add task", "Nova tarefa"], snapshotName: "03-add-task") {
            dismissSheet()
        }
        captureScreen(buttonLabels: ["Add event", "Novo evento"], snapshotName: "04-add-event") {
            dismissSheet()
        }
        captureScreen(buttonLabels: ["Show chat", "Mostrar chat"], snapshotName: "05-chat-interface") {
            dismissSheet()
        }
        captureScreen(buttonLabels: ["Show events", "Mostrar eventos"], snapshotName: "06-all-events") {
            let dismissButtons = ["Close event list", "Fechar lista de eventos"]
            for buttonName in dismissButtons {
                if app.buttons[buttonName].exists {
                    app.buttons[buttonName].tap()
                    return
                }
            }
        }
        captureScreen(buttonLabels: ["Show tasks", "Mostrar tasks"], snapshotName: "07-all-tasks") {
            let dismissButtons = ["Close task inbox", "Fechar caixa de tarefas"]
            for buttonName in dismissButtons {
                if app.buttons[buttonName].exists {
                    app.buttons[buttonName].tap()
                    return
                }
            }
        }
    }

    // MARK: - Screenshot Capture Methods

    private func captureMainScreen() {
        snapshot("01-today-view")
    }

    private func debugPrintButtons() {
        print("Available buttons:")
        for button in app.buttons.allElementsBoundByIndex {
            if button.exists {
                print("Button: \(button.identifier) - \(button.label)")
            }
        }
    }

    private func captureNavigation(buttonLabels: [String], snapshotName: String) {
        let button = findButton(labels: buttonLabels)
        if navigateToScreen(button: button, snapshotName: snapshotName) {
            navigateBack()
        }
    }

    private func captureScreen(buttonLabels: [String], snapshotName: String, dismiss: () -> Void) {
        let button = findButton(labels: buttonLabels)
        if presentSheet(button: button, snapshotName: snapshotName) {
            dismiss()
        }
    }

    // MARK: - Helper Methods

    private func findButton(labels: [String]) -> XCUIElement {
        var button = app.buttons[labels.first!]
        for label in labels {
            button = app.buttons[label]
            if button.exists {
                return button
            }
        }
        return button
    }

    private func navigateToScreen(button: XCUIElement, snapshotName: String) -> Bool {
        guard button.exists && button.isHittable else { return false }

        button.tap()
        sleep(2)
        snapshot(snapshotName)
        return true
    }

    private func presentSheet(button: XCUIElement, snapshotName: String) -> Bool {
        guard button.exists && button.isHittable else { return false }

        button.tap()
        sleep(2)
        snapshot(snapshotName)
        return true
    }

    private func navigateBack() {
        if app.navigationBars.buttons.count > 0 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        } else {
            app.swipeDown(velocity: XCUIGestureVelocity.fast)
        }
    }

    private func dismissSheet() {
        let dismissButtons = [
            "Cancel", "Cancelar",
            "Done", "Concluído",
            "Back", "Voltar"
        ]

        for buttonName in dismissButtons {
            if app.buttons[buttonName].exists {
                app.buttons[buttonName].tap()
                return
            }
        }

        // Fallback to gesture
        app.swipeDown(velocity: XCUIGestureVelocity.fast)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
