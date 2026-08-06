import XCTest

final class RTLPlaygroundUITests: PaymentSheetUITestCase {
    func testLayoutDirectionControlIsAvailable() {
        let settings = PaymentSheetTestPlaygroundSettings.defaultValues()

        loadPlayground(app, settings)

        XCTAssertTrue(app.staticTexts["Layout Direction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["System"].exists)
        XCTAssertTrue(app.buttons["LTR"].exists)
        XCTAssertTrue(app.buttons["RTL"].exists)
    }

    func testLayoutDirectionControlReordersPlaygroundHeader() {
        let settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        configureRightToLeftHost()

        loadPlayground(app, settings)

        let systemButton = app.buttons["System"]
        let leftToRightButton = app.buttons["LTR"]
        let rightToLeftButton = app.buttons["RTL"]
        XCTAssertTrue(systemButton.waitForExistence(timeout: 5))
        XCTAssertTrue(leftToRightButton.exists)
        XCTAssertTrue(rightToLeftButton.exists)

        assertPlaygroundHeaderIsRightToLeft()

        leftToRightButton.tap()
        assertPlaygroundHeaderIsLeftToRight()

        rightToLeftButton.tap()
        assertPlaygroundHeaderIsRightToLeft()

        systemButton.tap()
        assertPlaygroundHeaderIsRightToLeft()
    }

    func testLegacySettingsWithoutLayoutDirectionResolveToSystem() throws {
        let encodedSettings = try JSONEncoder().encode(PaymentSheetTestPlaygroundSettings.defaultValues())
        var legacySettings = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encodedSettings) as? [String: Any]
        )
        legacySettings.removeValue(forKey: "layoutDirection")
        let legacyData = try JSONSerialization.data(withJSONObject: legacySettings)

        let decodedSettings = try JSONDecoder().decode(
            PaymentSheetTestPlaygroundSettings.self,
            from: legacyData
        )

        XCTAssertNil(decodedSettings.layoutDirection)
        XCTAssertEqual(decodedSettings.resolvedLayoutDirection, .system)
    }

    func testLeftToRightLaunchOverridesRightToLeftHostDirection() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.layoutDirection = .leftToRight
        configureRightToLeftHost()

        loadPlayground(app, settings)

        let (resetButton, qrButton) = playgroundHeaderButtons()
        XCTAssertLessThan(resetButton.frame.midX, qrButton.frame.midX)
    }

    func testRightToLeftLaunchMirrorsPlaygroundHeader() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.layoutDirection = .rightToLeft

        loadPlayground(app, settings)

        let (resetButton, qrButton) = playgroundHeaderButtons()
        XCTAssertGreaterThan(resetButton.frame.midX, qrButton.frame.midX)
    }

    func testSystemLaunchPreservesRightToLeftHostDirection() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.layoutDirection = .system
        configureRightToLeftHost()

        loadPlayground(app, settings)

        let (resetButton, qrButton) = playgroundHeaderButtons()
        XCTAssertGreaterThan(resetButton.frame.midX, qrButton.frame.midX)
    }

    private func configureRightToLeftHost() {
        app.launchArguments += [
            "-AppleTextDirection", "YES",
            "-NSForceRightToLeftWritingDirection", "YES",
        ]
    }

    private func playgroundHeaderButtons() -> (reset: XCUIElement, qr: XCUIElement) {
        let resetButton = app.buttons["Reset"]
        let qrButton = app.buttons["QR"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertTrue(qrButton.waitForExistence(timeout: 5))
        return (resetButton, qrButton)
    }

    private func assertPlaygroundHeaderIsLeftToRight() {
        let (resetButton, qrButton) = playgroundHeaderButtons()
        XCTAssertLessThan(resetButton.frame.midX, qrButton.frame.midX)
    }

    private func assertPlaygroundHeaderIsRightToLeft() {
        let (resetButton, qrButton) = playgroundHeaderButtons()
        XCTAssertGreaterThan(resetButton.frame.midX, qrButton.frame.midX)
    }
}
