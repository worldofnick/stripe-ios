//
//  CheckoutElementsUITests.swift
//  PaymentSheet Example
//

import XCTest

final class CheckoutElementsUITests: PaymentSheetUITestCase {
    func testCurrencySelectorSwipingUpdatesCheckout() {
        checkCurrencySelectorSwipingUpdatesCheckout()
    }

    func testCurrencySelectorSwipingInRightToLeftLayout() {
        app.launchArguments += ["-AppleLanguages", "(ar)", "-AppleLocale", "ar", "-NSForceRightToLeftWritingDirection", "YES"]
        checkCurrencySelectorSwipingUpdatesCheckout()
    }

    private func checkCurrencySelectorSwipingUpdatesCheckout() {
        // Given a checkout with local and integration currencies
        app.launchEnvironment["STP_CHECKOUT_ELEMENTS"] = "true"
        app.launch()
        app.buttons["Reset"].waitForExistenceAndTap()
        app.buttons["No Override"].scrollToAndTap(in: app)
        app.buttons["Germany (DE)"].waitForExistenceAndTap()
        app.buttons["Create Checkout Session"].waitForExistenceAndTap()

        let euros = app.buttons["currency_option_eur"]
        let dollars = app.buttons["currency_option_usd"]
        XCTAssertTrue(euros.waitForExistence(timeout: 60))
        let lineItemAmount = app.staticTexts["checkout_line_item_amount"].firstMatch
        XCTAssertTrue(euros.isSelected)
        XCTAssertTrue(lineItemAmount.label.contains("€"))

        // When the customer grabs off-center and drags with natural finger drift
        euros.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: dollars.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
                .withOffset(CGVector(dx: 0, dy: -30)))

        // Then selection changes immediately and checkout finishes its network updates
        XCTAssertTrue(dollars.isSelected)
        expectation(for: NSPredicate(format: "label CONTAINS '$'"), evaluatedWith: lineItemAmount)
        expectation(for: NSPredicate(format: "selected == true AND enabled == true"), evaluatedWith: dollars)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["checkout_buy_button"])
        waitForExpectations(timeout: 60)
        XCTAssertFalse(euros.isSelected)

        // When the customer swipes back and their thumb finishes below the visual track
        let direction: CGFloat = euros.frame.midX < dollars.frame.midX ? -1 : 1
        let dividerX = (euros.frame.midX + dollars.frame.midX) / 2
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let nearDivider = origin.withOffset(CGVector(dx: dividerX - direction * 20, dy: dollars.frame.midY))
        let acrossDivider = origin.withOffset(CGVector(dx: dividerX + direction * 20, dy: euros.frame.midY))
        nearDivider.press(forDuration: 0.1, thenDragTo: acrossDivider.withOffset(CGVector(dx: direction * 120, dy: 80)))

        // Then checkout returns to the local currency
        XCTAssertTrue(euros.isSelected)
        expectation(for: NSPredicate(format: "label CONTAINS '€'"), evaluatedWith: lineItemAmount)
        expectation(for: NSPredicate(format: "selected == true AND enabled == true"), evaluatedWith: euros)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["checkout_buy_button"])
        waitForExpectations(timeout: 60)
        XCTAssertFalse(dollars.isSelected)

        // A short drag on the unselected option still selects that option
        let unselectedStart = dollars.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let towardSelection: CGFloat = euros.frame.midX < dollars.frame.midX ? -1 : 1
        unselectedStart.press(forDuration: 0.1, thenDragTo: unselectedStart.withOffset(CGVector(dx: towardSelection * 28, dy: 0)))
        XCTAssertTrue(dollars.isSelected)
        expectation(for: NSPredicate(format: "selected == true AND enabled == true"), evaluatedWith: dollars)
        expectation(for: NSPredicate(format: "label CONTAINS '$'"), evaluatedWith: lineItemAmount)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["checkout_buy_button"])
        waitForExpectations(timeout: 60)
        // Tapping still works after scrubbing
        euros.tap()
        expectation(for: NSPredicate(format: "selected == true AND enabled == true"), evaluatedWith: euros)
        expectation(for: NSPredicate(format: "label CONTAINS '€'"), evaluatedWith: lineItemAmount)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["checkout_buy_button"])
        waitForExpectations(timeout: 60)

        // Small finger adjustments do not switch; a deliberate short swipe does, even when held.
        for (from, to, symbol) in [(euros, dollars, "$"), (dollars, euros, "€")] {
            let direction: CGFloat = to.frame.midX < from.frame.midX ? -1 : 1
            let start = from.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: direction * 29, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.2)
            XCTAssertTrue(from.isSelected)
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: direction * 32, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.2)
            XCTAssertTrue(to.isSelected)
            expectation(for: NSPredicate(format: "label CONTAINS %@", symbol), evaluatedWith: lineItemAmount)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["checkout_buy_button"])
            waitForExpectations(timeout: 60)
        }

        // Three quarters of the distance to the divider is enough to change currency.
        for (from, to, symbol) in [(euros, dollars, "$"), (dollars, euros, "€")] {
            let dividerX = (from.frame.midX + to.frame.midX) / 2
            let start = from.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = origin.withOffset(CGVector(dx: from.frame.midX + (dividerX - from.frame.midX) * 0.75, dy: to.frame.midY))
            start.press(forDuration: 0.1, thenDragTo: end)
            XCTAssertTrue(to.isSelected)
            expectation(for: NSPredicate(format: "label CONTAINS %@", symbol), evaluatedWith: lineItemAmount)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["checkout_buy_button"])
            waitForExpectations(timeout: 60)
        }

        // Fast reversals without a hold work regardless of which side of the pill was grabbed.
        for verticalDrift: CGFloat in [24, -24] {
            for (from, to, symbol) in [(euros, dollars, "$"), (dollars, euros, "€")] {
                let direction: CGFloat = to.frame.midX < from.frame.midX ? -1 : 1
                let dividerX = (from.frame.midX + to.frame.midX) / 2
                let start = origin.withOffset(CGVector(dx: dividerX - direction * 20, dy: from.frame.midY))
                let end = origin.withOffset(CGVector(dx: dividerX + direction * 20, dy: to.frame.midY + verticalDrift))
                start.press(forDuration: 0, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
                XCTAssertTrue(to.isSelected)
                expectation(for: NSPredicate(format: "label CONTAINS %@", symbol), evaluatedWith: lineItemAmount)
                expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["checkout_buy_button"])
                waitForExpectations(timeout: 60)
            }
        }

        // When the customer scrolls vertically starting on the selector
        let originalY = euros.frame.minY
        let start = euros.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -80)))

        // Then checkout scrolls without changing currency
        expectation(for: NSPredicate { _, _ in euros.frame.minY < originalY }, evaluatedWith: euros)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(euros.isSelected)
        XCTAssertTrue(lineItemAmount.label.contains("€"))
    }

    func testElementsStaySynchronizedWithCheckoutSession() throws {
        // Given a Checkout Session
        app.launchEnvironment["STP_CHECKOUT_ELEMENTS"] = "true"
        app.launch()

        app.buttons["Reset"].waitForExistenceAndTap()
        app.buttons["No Override"].scrollToAndTap(in: app)
        app.buttons["Germany (DE)"].waitForExistenceAndTap()
        app.buttons["Create Checkout Session"].waitForExistenceAndTap()

        XCTAssertTrue(app.navigationBars["Your Cart"].waitForExistence(timeout: 15))
        let lineItemAmount = app.staticTexts["checkout_line_item_amount"].firstMatch
        let subtotalAmount = app.staticTexts["checkout_subtotal_amount"]
        let totalAmount = app.staticTexts["checkout_total_amount"]
        let buyButton = app.buttons["checkout_buy_button"]
        let taxPrompt = app.descendants(matching: .any)["checkout_tax_prompt"]
        XCTAssertTrue(lineItemAmount.waitForExistence(timeout: 10))
        XCTAssertTrue(subtotalAmount.exists)
        XCTAssertTrue(totalAmount.exists)
        XCTAssertTrue(buyButton.exists)
        XCTAssertTrue(taxPrompt.exists)

        // Then the merchant surface and Payment Element reflect the localized Session
        XCTAssertTrue(lineItemAmount.label.contains("€"))
        XCTAssertTrue(subtotalAmount.label.contains("€"))
        XCTAssertEqual(totalAmount.label, subtotalAmount.label)
        XCTAssertTrue(buyButton.label.contains(totalAmount.label))
        XCTAssertTrue(app.buttons["Select payment method"].exists)

        // When the customer selects the integration currency in Currency Selector Element
        let usdCurrencyOption = app.buttons["currency_option_usd"]
        usdCurrencyOption.waitForExistenceAndTap()

        // Then every merchant-owned amount reflects the new Session
        expectation(
            for: NSPredicate(format: "label == %@", "$120.00"),
            evaluatedWith: totalAmount,
            handler: nil
        )
        waitForExpectations(timeout: 10)
        XCTAssertTrue(lineItemAmount.label.contains("$"))
        XCTAssertEqual(subtotalAmount.label, "$120.00")
        XCTAssertTrue(buyButton.label.contains("$120.00"))
        expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: usdCurrencyOption,
            handler: nil
        )
        waitForExpectations(timeout: 10)

        // When the customer saves an address in Shipping Address Element
        let scrollStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let scrollEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        scrollStart.press(forDuration: 0.1, thenDragTo: scrollEnd)
        app.buttons["Add shipping address"].scrollToAndTap(in: app)
        fillShippingAddress()

        let saveAddressButton = app.buttons["Save Address"]
        XCTAssertTrue(saveAddressButton.isEnabled)
        saveAddressButton.tap()

        // Then the merchant surface reflects the new Session
        XCTAssertTrue(app.staticTexts["Jane Doe"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["510 Townsend St"].exists)
        expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: taxPrompt,
            handler: nil
        )
        waitForExpectations(timeout: 10)
        let taxAmount = app.staticTexts["checkout_tax_amount"]
        XCTAssertTrue(taxAmount.waitForExistence(timeout: 10))
        XCTAssertTrue(taxAmount.label.contains("$"))
        XCTAssertNotEqual(taxAmount.label, "$0.00")
        XCTAssertEqual(subtotalAmount.label, "$120.00")
        XCTAssertNotEqual(totalAmount.label, subtotalAmount.label)
        XCTAssertTrue(buyButton.label.contains(totalAmount.label))

        // When the customer selects a card in Payment Element
        app.buttons["Select payment method"].scrollToAndTap(in: app)
        if !app.textFields["Card number"].waitForExistence(timeout: 2) {
            app.buttons["Add new payment method"].forceTapWhenHittableInTestCase(self)
        }
        if !app.textFields["Card number"].waitForExistence(timeout: 2) {
            app.buttons["+ Add"].forceTapWhenHittableInTestCase(self)
        }
        try fillCardData(app)
        app.stp_dismissKeyboard()
        app.buttons["Continue"].forceTapWhenHittableInTestCase(self)

        // Then the merchant surface reflects the selected payment method after Checkout updates.
        XCTAssertTrue(app.staticTexts["•••• 4242"].waitForExistence(timeout: 10))
        buyButton.scrollToAndTap(in: app)

        XCTAssertTrue(app.alerts["Success"].waitForExistence(timeout: 20))
    }

    private func fillShippingAddress() {
        app.textFields["Full name"].waitForExistenceAndTap()
        app.typeText("Jane Doe")

        app.textFields["Address"].waitForExistenceAndTap()
        app.buttons["Enter address manually"].waitForExistenceAndTap()

        app.textFields["Address line 1"].waitForExistenceAndTap()
        app.typeText("510 Townsend St")

        app.textFields["City"].tap()
        app.typeText("San Francisco")

        app.textFields["State"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "California")

        app.textFields["ZIP"].tap()
        app.typeText("94102")
    }
}
