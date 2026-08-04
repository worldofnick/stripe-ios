//
//  AddressViewControllerDismissalIssueUITests.swift
//  PaymentSheetUITest
//

import XCTest

final class AddressViewControllerDismissalIssueUITests: PaymentSheetUITestCase {

    // MARK: - Helpers

    private func loadAddressPlayground(
        shippingInfo: PaymentSheetTestPlaygroundSettings.ShippingInfo = .on
    ) {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.layout = .horizontal
        settings.uiStyle = .flowController
        settings.shippingInfo = shippingInfo
        loadPlayground(app, settings)
    }

    private func navigateToShippingAddress() {
        let shippingButton = app.buttons["Address"]
        XCTAssertTrue(shippingButton.waitForExistence(timeout: 4.0))
        shippingButton.tap()
    }

    private func saveAddress() {
        let saveAddressButton = app.buttons["Save address"]
        XCTAssertTrue(saveAddressButton.waitForExistence(timeout: 4.0))
        XCTAssertTrue(saveAddressButton.isEnabled)
        saveAddressButton.tap()
    }

    private func fillAutocompleteAddress() {
        app.textFields["Full name"].tap()
        app.typeText("Jane Doe")

        app.textFields["Address"].waitForExistenceAndTap()
        app.typeText("354 Oyster Point")
        let searchedCell = app.tables.element(boundBy: 0).cells.containing(
            NSPredicate(format: "label CONTAINS %@", "354 Oyster Point Blvd")
        ).element
        XCTAssertTrue(searchedCell.waitForExistence(timeout: 5.0))
        searchedCell.tap()

        app.textFields["Phone number"].tap()
        app.typeText("5555555555")
    }

    private func waitForAnalyticsEventCount(
        _ event: String,
        expectedCount: Int,
        timeout: TimeInterval = 2.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in
                self?.analyticsLog.filter { $0[string: "event"] == event }.count == expectedCount
            },
            object: analyticsLogElement
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(
            analyticsLog.filter { $0[string: "event"] == event }.count,
            expectedCount,
            file: file,
            line: line
        )
    }

    // MARK: - Issue Reproductions

    // Issue: Changing only an empty phone field's country is omitted from `hasChanges`, so Close dismisses without confirmation.
    func testDismissingAfterChangingEmptyPhoneCountryShowsDiscardConfirmation() {
        // Given an empty address form with an optional phone field
        loadAddressPlayground()
        navigateToShippingAddress()

        // When the customer changes only the phone country
        let unitedStatesPhoneCountry = app.textFields["United States +1"]
        XCTAssertTrue(unitedStatesPhoneCountry.waitForExistence(timeout: 2.0))
        unitedStatesPhoneCountry.tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "🇬🇧 United Kingdom +44")
        app.stp_dismissKeyboard()
        XCTAssertTrue(app.textFields["United Kingdom +44"].exists)

        // ...and tries to close the form
        app.buttons["Close"].tap()

        // Then the form should treat the phone-country selection as an unsaved change
        XCTAssertTrue(app.alerts["Discard changes?"].waitForExistence(timeout: 2.0))
    }

    // Issue: Discard restores field values but not compact-autocomplete mode, so a reused controller reopens in manual-entry mode.
    func testDiscardingManualEntryRestoresCompactAutocompleteOnReopen() {
        // Given an empty address form using compact autocomplete
        loadAddressPlayground()
        navigateToShippingAddress()
        XCTAssertTrue(app.textFields["Address"].waitForExistence(timeout: 2.0))
        XCTAssertFalse(app.textFields["Address line 1"].exists)

        // When the customer makes a change, switches to manual entry, and discards
        app.textFields["Full name"].tap()
        app.typeText("Jane Doe")
        app.textFields["Address"].tap()
        XCTAssertTrue(app.buttons["Enter address manually"].waitForExistenceAndTap())
        XCTAssertTrue(app.textFields["Address line 1"].waitForExistence(timeout: 2.0))

        app.buttons["Close"].tap()
        let discardChangesAlert = app.alerts["Discard changes?"]
        XCTAssertTrue(discardChangesAlert.waitForExistence(timeout: 2.0))
        discardChangesAlert.buttons["Discard Changes"].tap()

        // ...and the same controller is presented again
        navigateToShippingAddress()

        // Then the form should be restored to its original compact-autocomplete presentation
        XCTAssertTrue(app.textFields["Address"].waitForExistence(timeout: 2.0))
        XCTAssertFalse(app.textFields["Address line 1"].exists)
    }

    // Issue: `selectedAutoCompleteResult` survives dismissal, so the next presentation reports autocomplete that it did not use.
    func testReusingAddressControllerDoesNotReuseAutocompleteAnalytics() throws {
        // Given an empty address form completed with autocomplete
        loadAddressPlayground()
        navigateToShippingAddress()
        fillAutocompleteAddress()
        saveAddress()

        let firstCompletionEvents = analyticsLog.filter { $0[string: "event"] == "mc_address_completed" }
        XCTAssertEqual(firstCompletionEvents.count, 1)

        // When the same controller is presented and saved again without selecting autocomplete
        navigateToShippingAddress()
        saveAddress()

        // Then the second completion should not reuse autocomplete state from the first presentation
        let completionEvents = analyticsLog.filter { $0[string: "event"] == "mc_address_completed" }
        XCTAssertEqual(completionEvents.count, 2)
        let secondAddressData = try XCTUnwrap(completionEvents.last?["address_data_blob"] as? [String: Any])
        XCTAssertEqual(secondAddressData["auto_complete_result_selected"] as? Bool, false)
    }

    // Issue: `didLogAddressShow` is never reset, so a reused controller logs only its first presentation.
    func testReusingAddressControllerLogsShowForEachPresentation() {
        // Given a valid pre-populated address form
        loadAddressPlayground(shippingInfo: .onWithDefaults)
        navigateToShippingAddress()
        waitForAnalyticsEventCount("mc_address_show", expectedCount: 1)

        // When the address is saved and the same controller is presented again
        saveAddress()
        navigateToShippingAddress()

        // Then each presentation should emit its own show event
        waitForAnalyticsEventCount("mc_address_show", expectedCount: 2)
    }
}
