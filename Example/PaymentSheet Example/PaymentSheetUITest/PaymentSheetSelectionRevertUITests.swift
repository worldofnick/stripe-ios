//
//  PaymentSheetSelectionRevertUITests.swift
//  PaymentSheetUITest
//

import XCTest

/// Tests that cancelling the sheet (tapping X, tapping outside, or swiping down) reverts the
/// payment method selection — both the developer-facing `paymentOption` and the locally
/// persisted default — back to whatever was selected when the sheet was presented.
///
/// Note: in the horizontal layout, tapping an Apple Pay/Link/saved card tile commits the selection
/// and closes the sheet immediately, so the cancellable selection changes there are limited to
/// tiles that require a mandate (e.g. US bank account) and the add-card form.
class PaymentSheetSelectionRevertUITests: PaymentSheetUITestCase {

    // MARK: - FlowController, vertical layout

    func testFlowControllerVertical_cancelRevertsToSavedPM_persistenceReverted() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .vertical
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        settings.allowsDelayedPMs = .off // Hide the saved bank account so •••• 4242 is the only saved PM
        settings.applePayEnabled = .off // With Apple Pay off, the saved card is the initial selection
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Change selection to Cash App Pay, then cancel via the X button
        paymentMethodButton.tap()
        app.buttons["Cash App Pay"].waitForExistenceAndTap()
        XCTAssertTrue(app.buttons["Cash App Pay"].isSelected)
        app.buttons["Close"].waitForExistenceAndTap()

        // Selection should revert to the saved card
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Re-open: the saved card should be selected, not Cash App Pay
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["•••• 4242"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["•••• 4242"].isSelected)
        XCTAssertFalse(app.buttons["Cash App Pay"].isSelected)
        app.buttons["Close"].waitForExistenceAndTap()
        sleep(1)

        // Reload: the persisted default should still be the saved card
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")
    }

    func testFlowControllerVertical_tapOutsideCancel_revertsToApplePay() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .vertical
        settings.customerMode = .new
        settings.apmsEnabled = .off
        settings.supportedPaymentMethods = "card,cashapp" // Keep the sheet short so tapping (100, 100) lands outside it
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        XCTAssertEqual(paymentMethodButton.label, "Apple Pay, apple_pay")

        // Change selection to Cash App Pay, then cancel by tapping outside the sheet
        paymentMethodButton.tap()
        app.buttons["Cash App Pay"].waitForExistenceAndTap()
        app.tapCoordinate(at: CGPoint(x: 100, y: 100))

        // Selection should revert to Apple Pay
        waitForLabel(paymentMethodButton, hasPrefix: "Apple Pay")

        // Re-open: Apple Pay should be selected
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Apple Pay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Apple Pay"].isSelected)
        XCTAssertFalse(app.buttons["Cash App Pay"].isSelected)
        app.buttons["Close"].waitForExistenceAndTap()
        sleep(1)

        // Reload: persisted default should still be Apple Pay
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "Apple Pay")
    }

    func testFlowControllerVertical_cancelRevertsLinkSelection() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .vertical
        settings.customerMode = .new
        settings.linkPassthroughMode = .pm
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        XCTAssertEqual(paymentMethodButton.label, "Apple Pay, apple_pay")

        // Select the Link row (which persists Link as the local default), then cancel
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["Link"].waitForExistenceAndTap())
        app.buttons["Close"].waitForExistenceAndTap()

        // Selection should revert to Apple Pay
        waitForLabel(paymentMethodButton, hasPrefix: "Apple Pay")

        // Re-open: Link should not be selected
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Apple Pay"].isSelected)
        XCTAssertFalse(app.buttons["Link"].isSelected)
        app.buttons["Close"].waitForExistenceAndTap()
        sleep(1)

        // Reload: persisted default should not be Link
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "Apple Pay")
    }

    func testFlowControllerVertical_cancelAfterFillingNewCardForm_revertsToSavedPM() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .vertical
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        settings.allowsDelayedPMs = .off
        settings.applePayEnabled = .off // With Apple Pay off, the saved card is the initial selection
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Fill out a complete new card form, then cancel by tapping outside
        // (the form screen has no X button; the first tap dismisses the keyboard)
        paymentMethodButton.tap()
        app.buttons["New card"].waitForExistenceAndTap()
        try! fillCardData(app, cardNumber: "5555555555554444", postalEnabled: true)
        app.tapCoordinate(at: CGPoint(x: 200, y: 100))
        app.tapCoordinate(at: CGPoint(x: 200, y: 100))

        // Selection should revert to the saved card, not the new card
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Re-open: saved card selected, and the form should have retained its input (formCache preserved)
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["•••• 4242"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["•••• 4242"].isSelected)
        app.buttons["New card"].waitForExistenceAndTap()
        XCTAssertEqual(app.textFields["Card number"].value as? String, "5555555555554444", "Form input should be preserved after cancel")
    }

    func testFlowControllerVertical_cancelRevertsToNone() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .vertical
        settings.customerMode = .new
        settings.applePayEnabled = .off
        settings.linkEnabledMode = .off
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        XCTAssertEqual(paymentMethodButton.label, "None")

        // Select Cash App Pay, then cancel
        paymentMethodButton.tap()
        app.buttons["Cash App Pay"].waitForExistenceAndTap()
        app.buttons["Close"].waitForExistenceAndTap()

        // Selection should revert to None
        waitForLabel(paymentMethodButton, hasPrefix: "None")

        // Re-open: nothing should be selected
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["Cash App Pay"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Cash App Pay"].isSelected)
    }

    func testFlowControllerVertical_deleteSelectedPM_thenCancel_gracefulFallback() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .vertical
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))

        // Commit •••• 4242 as the baseline selection
        paymentMethodButton.tap()
        ensureVerticalSPMSelection("•••• 4242", insteadOf: "••••6789")
        tapContinueRevealingIfNeeded()
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Delete the selected card from the manage screen, then cancel the sheet
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["View more"].waitForExistenceAndTap())
        XCTAssertTrue(app.buttons["Edit"].waitForExistenceAndTap())
        tapChevron(for: "•••• 4242")
        XCTAssertTrue(app.buttons["Remove"].waitForExistenceAndTap())
        XCTAssertTrue(app.alerts.buttons["Remove"].waitForExistenceAndTap())
        sleep(2)
        // With one PM remaining the manage screen auto-dismisses back to the list;
        // tap Done first if it's still showing.
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }
        XCTAssertTrue(app.buttons["Close"].waitForExistenceAndTap())
        sleep(2)

        // Revert is impossible (the card is gone) — the sheet's auto-selection should be kept
        XCTAssertFalse(paymentMethodButton.label.hasPrefix("•••• 4242"), "Deleted card should not be the selection")

        // Reload: the deleted card must not come back as the persisted default
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        XCTAssertFalse(paymentMethodButton.label.hasPrefix("•••• 4242"), "Deleted card should not be the persisted default")
        // And it should be gone from the list entirely
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["••••6789"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["•••• 4242"].exists)
    }

    func testFlowControllerVertical_deleteNonSelectedPM_thenCancel_stillReverts() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .vertical
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))

        // Commit •••• 4242 as the baseline selection
        paymentMethodButton.tap()
        ensureVerticalSPMSelection("•••• 4242", insteadOf: "••••6789")
        tapContinueRevealingIfNeeded()
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Delete the OTHER saved PM, then change selection, then cancel
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["View more"].waitForExistenceAndTap())
        XCTAssertTrue(app.buttons["Edit"].waitForExistenceAndTap())
        tapChevron(for: "••••6789")
        XCTAssertTrue(app.buttons["Remove"].waitForExistenceAndTap())
        XCTAssertTrue(app.alerts.buttons["Remove"].waitForExistenceAndTap())
        sleep(2)
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }
        // Change selection to Cash App Pay before cancelling
        XCTAssertTrue(app.buttons["Cash App Pay"].waitForExistenceAndTap())
        XCTAssertTrue(app.buttons["Close"].waitForExistenceAndTap())

        // The original selection still exists, so it should be fully reverted
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Reload: persisted default reverted, and the deletion stuck
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["•••• 4242"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["••••6789"].exists)
    }

    // MARK: - FlowController, horizontal layout

    func testFlowControllerHorizontal_cancelRevertsToSavedPM_persistenceReverted() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .horizontal
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))

        // Commit •••• 4242 as the baseline selection (tapping a card tile commits and closes)
        paymentMethodButton.tap()
        XCTAssertNotNil(scroll(collectionView: app.collectionViews.firstMatch, toFindCellWithId: "•••• 4242"))
        app.collectionViews.buttons["•••• 4242"].tap()
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Select the bank account (requires a mandate, so the sheet stays open and the
        // selection is persisted at tap time), then cancel via the X button
        paymentMethodButton.tap()
        XCTAssertNotNil(scroll(collectionView: app.collectionViews.firstMatch, toFindCellWithId: "••••6789"))
        app.collectionViews.buttons["••••6789"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistenceAndTap())

        // Selection should revert to the saved card
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Reload: persisted default should still be the saved card
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")
    }

    func testFlowControllerHorizontal_cancelAfterFilledAddCardForm_reverts() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .horizontal
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        settings.allowsDelayedPMs = .off
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))

        // Commit •••• 4242 as the baseline selection
        paymentMethodButton.tap()
        XCTAssertNotNil(scroll(collectionView: app.collectionViews.firstMatch, toFindCellWithId: "•••• 4242"))
        app.collectionViews.buttons["•••• 4242"].tap()
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Fill a complete card in the add screen, then cancel by tapping outside
        paymentMethodButton.tap()
        XCTAssertTrue(app.buttons["+ Add"].waitForExistenceAndTap())
        try! fillCardData(app)
        app.tapCoordinate(at: CGPoint(x: 100, y: 100))

        // Selection should revert to the saved card, not the new card
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Reload: persisted default unchanged
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")
    }

    func testFlowControllerHorizontal_deleteSelectedPM_thenCancel_gracefulFallback() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .horizontal
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        settings.allowsDelayedPMs = .off // •••• 4242 is the only saved PM — deleting it also covers the "all PMs deleted" case
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))

        // Commit •••• 4242 as the baseline selection
        paymentMethodButton.tap()
        XCTAssertNotNil(scroll(collectionView: app.collectionViews.firstMatch, toFindCellWithId: "•••• 4242"))
        app.collectionViews.buttons["•••• 4242"].tap()
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Delete the (only) saved card, then cancel the sheet
        paymentMethodButton.tap()
        XCTAssertTrue(app.staticTexts["Edit"].waitForExistenceAndTap())
        // The edit button can be off-screen in the carousel; scroll a little
        let startCoordinate = app.collectionViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.99))
        startCoordinate.press(forDuration: 0.1, thenDragTo: app.collectionViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.99)))
        XCTAssertTrue(app.buttons.matching(identifier: "CircularButton.Edit").firstMatch.waitForExistenceAndTap())
        XCTAssertTrue(app.buttons["Remove"].waitForExistenceAndTap())
        XCTAssertTrue(app.alerts.buttons["Remove"].waitForExistenceAndTap())
        sleep(2)
        XCTAssertTrue(app.buttons["Close"].waitForExistenceAndTap())
        sleep(2)

        // Revert is impossible — the fallback selection must not be the deleted card
        XCTAssertFalse(paymentMethodButton.label.hasPrefix("•••• 4242"), "Deleted card should not be the selection")

        // Reload: consistent — deleted card is not the persisted default
        reload(app, settings: settings)
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))
        XCTAssertFalse(paymentMethodButton.label.hasPrefix("•••• 4242"), "Deleted card should not be the persisted default")
    }

    func testFlowControllerHorizontal_swipeDownDismiss_reverts() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .flowController
        settings.layout = .horizontal
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        loadPlayground(app, settings)

        let paymentMethodButton = app.buttons["Payment method"]
        XCTAssertTrue(paymentMethodButton.waitForExistence(timeout: 10))

        // Commit •••• 4242 as the baseline selection
        paymentMethodButton.tap()
        XCTAssertNotNil(scroll(collectionView: app.collectionViews.firstMatch, toFindCellWithId: "•••• 4242"))
        app.collectionViews.buttons["•••• 4242"].tap()
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")

        // Select the bank account (keeps the sheet open), then dismiss by dragging the sheet down
        paymentMethodButton.tap()
        XCTAssertNotNil(scroll(collectionView: app.collectionViews.firstMatch, toFindCellWithId: "••••6789"))
        app.collectionViews.buttons["••••6789"].tap()
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        let start = closeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 600))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Selection should revert to the saved card
        waitForLabel(paymentMethodButton, hasPrefix: "•••• 4242")
    }

    // MARK: - PaymentSheet (full sheet) — persistence is the only observable

    func testPaymentSheetVertical_cancelDoesNotPersistChangedSelection() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .paymentSheet
        settings.layout = .vertical
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        loadPlayground(app, settings)

        // Baseline: ensure •••• 4242 is the selected saved PM and commit it by paying
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        ensureVerticalSPMSelection("•••• 4242", insteadOf: "••••6789")
        let payButton = app.buttons["Pay $50.99"]
        XCTAssertTrue(payButton.waitForExistence(timeout: 5))
        sleep(1) // Let the sheet settle after the manage screen pops
        payButton.tap()
        XCTAssertTrue(app.staticTexts["Success!"].waitForExistence(timeout: 15))
        reload(app, settings: settings)

        // Present, switch to the bank account via the manage screen (which persists at tap
        // time today), then cancel
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(app.buttons["•••• 4242"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["•••• 4242"].isSelected)
        XCTAssertTrue(app.buttons["View more"].waitForExistenceAndTap())
        XCTAssertTrue(app.buttons["••••6789"].waitForExistenceAndTap())
        XCTAssertTrue(app.buttons["••••6789"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].waitForExistenceAndTap())
        sleep(2)

        // Re-present: the saved card should still be the initial selection
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(app.buttons["•••• 4242"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["•••• 4242"].isSelected, "Cancelled selection should not persist across presentations")
        app.buttons["Close"].waitForExistenceAndTap()
        sleep(1)

        // Reload: same story
        reload(app, settings: settings)
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(app.buttons["•••• 4242"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["•••• 4242"].isSelected, "Cancelled selection should not persist across reloads")
    }

    func testPaymentSheetHorizontal_cancelDoesNotPersistChangedSelection() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .paymentSheet
        settings.layout = .horizontal
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        settings.allowsDelayedPMs = .off
        loadPlayground(app, settings)

        // Baseline: pay with the saved card so it becomes the persisted default
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        let savedCardTile = app.collectionViews.buttons["•••• 4242"]
        XCTAssertNotNil(scroll(collectionView: app.collectionViews.firstMatch, toFindCellWithId: "•••• 4242"))
        savedCardTile.tap()
        app.buttons["Pay $50.99"].waitForExistenceAndTap()
        XCTAssertTrue(app.staticTexts["Success!"].waitForExistence(timeout: 15))
        reload(app, settings: settings)

        // Present: the saved card should be the initial selection; change to Apple Pay, then cancel
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(savedCardTile.waitForExistence(timeout: 10))
        XCTAssertTrue(savedCardTile.isSelected)
        app.collectionViews.buttons["Apple Pay"].waitForExistenceAndTap()
        app.buttons["Close"].waitForExistenceAndTap()
        sleep(2)

        // Re-present: the saved card should still be the initial selection
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(savedCardTile.waitForExistence(timeout: 10))
        XCTAssertTrue(savedCardTile.isSelected, "Cancelled selection should not persist across presentations")
        app.buttons["Close"].waitForExistenceAndTap()
        sleep(1)

        // Reload: same story
        reload(app, settings: settings)
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(savedCardTile.waitForExistence(timeout: 10))
        XCTAssertTrue(savedCardTile.isSelected, "Cancelled selection should not persist across reloads")
    }

    func testPaymentSheetVertical_deleteSelectedPM_thenCancel_gracefulFallback() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.uiStyle = .paymentSheet
        settings.layout = .vertical
        settings.customerMode = .returning
        settings.customerKeyType = .legacy
        loadPlayground(app, settings)

        // Baseline: ensure •••• 4242 is the selected saved PM
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        ensureVerticalSPMSelection("•••• 4242", insteadOf: "••••6789")

        // Delete the selected card from the manage screen, then cancel the sheet
        XCTAssertTrue(app.buttons["View more"].waitForExistenceAndTap())
        XCTAssertTrue(app.buttons["Edit"].waitForExistenceAndTap())
        tapChevron(for: "•••• 4242")
        XCTAssertTrue(app.buttons["Remove"].waitForExistenceAndTap())
        XCTAssertTrue(app.alerts.buttons["Remove"].waitForExistenceAndTap())
        sleep(2)
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }
        XCTAssertTrue(app.buttons["Close"].waitForExistenceAndTap())
        sleep(2)

        // Re-present: deleted card gone, remaining PM shown
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(app.buttons["••••6789"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["•••• 4242"].exists, "Deleted card should be gone")
        app.buttons["Close"].waitForExistenceAndTap()
        sleep(1)

        // Reload: consistent
        reload(app, settings: settings)
        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        XCTAssertTrue(app.buttons["••••6789"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["•••• 4242"].exists, "Deleted card should be gone after reload")
    }

    // MARK: - Helpers

    /// Taps the sheet's Continue button, swiping the (potentially long) vertical list up first
    /// if the button is below the fold.
    private func tapContinueRevealingIfNeeded() {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        if !continueButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(continueButton.isHittable, "Continue button should be tappable after scrolling")
        continueButton.tap()
    }

    /// Waits for the element's label to begin with the given prefix, e.g. the FlowController
    /// "Payment method" button label, which updates asynchronously after the sheet dismisses.
    private func waitForLabel(_ element: XCUIElement, hasPrefix prefix: String, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected label to begin with \"\(prefix)\", got \"\(element.label)\"")
    }

    /// Returning customers have two saved payment methods in a non-deterministic order.
    /// Ensures `label1` is the selected saved PM in a vertical list before the test proceeds.
    private func ensureVerticalSPMSelection(_ label1: String, insteadOf label2: String) {
        let timeout: TimeInterval = 10.0
        if app.buttons[label1].waitForExistence(timeout: timeout) {
            if !app.buttons[label1].isSelected {
                app.buttons[label1].tap()
            }
        } else {
            XCTAssertTrue(app.buttons[label2].waitForExistence(timeout: timeout), "Unable to find either \(label1) or \(label2)")
            XCTAssertTrue(app.buttons["View more"].waitForExistenceAndTap(timeout: timeout))
            XCTAssertTrue(app.buttons[label1].waitForExistenceAndTap(timeout: timeout))
            sleep(1) // Allow the manage screen to pop back to the list
            XCTAssertTrue(app.buttons["View more"].waitForExistence(timeout: timeout), "Should be back on the main list after selecting in the manage screen")
        }
        XCTAssertTrue(app.buttons[label1].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons[label1].isSelected, "\(label1) should be selected after ensuring selection")
    }

    /// Taps the edit chevron for the saved PM row with the given label in the manage screen,
    /// falling back to the first chevron if the row can't be targeted directly.
    private func tapChevron(for label: String) {
        let rowChevron = app.otherElements[label].buttons["chevron"]
        if rowChevron.waitForExistence(timeout: 2) {
            rowChevron.tap()
        } else {
            XCTAssertTrue(app.buttons["chevron"].firstMatch.waitForExistenceAndTap())
        }
    }
}
