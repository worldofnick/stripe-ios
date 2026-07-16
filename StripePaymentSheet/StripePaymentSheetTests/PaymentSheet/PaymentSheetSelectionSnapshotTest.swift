//
//  PaymentSheetSelectionSnapshotTest.swift
//  StripePaymentSheetTests
//

@testable @_spi(STP) import StripePayments
@testable @_spi(STP) import StripePaymentSheet
import XCTest

final class PaymentSheetSelectionSnapshotTest: XCTestCase {
    private let customerID = "cus_selection_snapshot_test"

    override func tearDown() {
        CustomerPaymentOption.setDefaultPaymentMethod(nil, forCustomer: customerID)
        super.tearDown()
    }

    func testClearingLinkSelectionDoesNotResurrectPersistedLinkOnRestore() {
        // Given Link is the selection and the persisted default when the sheet is presented
        CustomerPaymentOption.setDefaultPaymentMethod(.link, forCustomer: customerID)
        let snapshot = SelectionSnapshot.capture(
            paymentOption: .link(option: .wallet(brand: .link)),
            customerID: customerID
        )

        // When the user drops out of the native Link flow (which deliberately clears the selection)...
        let cleared = snapshot.clearingLinkSelection
        XCTAssertNil(cleared.paymentOption)

        // ...and then cancels the sheet
        cleared.restoreLocalPersistence(customerID: customerID, savedPaymentMethods: [])

        // Then Link must not remain the persisted default while the in-memory selection is nil
        XCTAssertNil(
            CustomerPaymentOption.localDefaultPaymentMethod(for: customerID),
            "The persisted default should not remain Link after the Link selection was deliberately cleared"
        )
    }

    func testClearingLinkSelectionPreservesNonLinkPersistedDefault() {
        // Given a saved card is the persisted default, but Link is the in-memory selection
        let paymentMethod = STPPaymentMethod._testCard()
        CustomerPaymentOption.setDefaultPaymentMethod(.stripeId(paymentMethod.stripeId), forCustomer: customerID)
        let snapshot = SelectionSnapshot.capture(
            paymentOption: .link(option: .wallet(brand: .link)),
            customerID: customerID
        )

        // When the user drops out of the native Link flow and then cancels
        let cleared = snapshot.clearingLinkSelection
        cleared.restoreLocalPersistence(customerID: customerID, savedPaymentMethods: [paymentMethod])

        // Then the unrelated persisted default is untouched
        XCTAssertEqual(
            CustomerPaymentOption.localDefaultPaymentMethod(for: customerID),
            .stripeId(paymentMethod.stripeId)
        )
    }
}
