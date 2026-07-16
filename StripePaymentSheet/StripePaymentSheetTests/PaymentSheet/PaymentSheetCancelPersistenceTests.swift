//
//  PaymentSheetCancelPersistenceTests.swift
//  StripePaymentSheetTests
//

@_spi(STP) import StripeCore
@testable @_spi(STP) import StripePayments
@testable @_spi(STP) import StripePaymentSheet
@_spi(STP) import StripePaymentsTestUtils
@_spi(STP) import StripeUICore
import XCTest

/// Covers full PaymentSheet's cancel behavior: an abandoned selection change must not stick as the
/// locally persisted default. Drives the same code paths as the (slow) selection-revert UI tests,
/// headlessly: present-time snapshot → row tap (persists) → cancel delegate → persistence reverted.
final class PaymentSheetCancelPersistenceTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        let expectation = expectation(description: "specs loaded")
        AddressSpecProvider.shared.loadAddressSpecs {
            FormSpecProvider.shared.load { _ in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }

    private func makeLoadResult(savedPaymentMethods: [STPPaymentMethod]) -> PaymentSheetLoader.LoadResult {
        return PaymentSheetLoader.LoadResult(
            intent: ._testPaymentIntent(paymentMethodTypes: [.card]),
            elementsSession: ._testValue(paymentMethodTypes: ["card"]),
            savedPaymentMethods: savedPaymentMethods,
            paymentMethodTypes: [.stripe(.card)],
            paymentMethodMessagingPromotionsHelper: ._testValue(),
            paymentMethodOrientation: .vertical
        )
    }

    private func makeConfiguration(customerID: String) -> PaymentSheet.Configuration {
        var config = PaymentSheet.Configuration._testValue_MostPermissive(isApplePayEnabled: false)
        config.customer = .init(id: customerID, ephemeralKeySecret: "ek_test")
        return config
    }

    func testVerticalCancel_revertsPersistedDefault() throws {
        // Given card A is the persisted default when the sheet is presented
        let customerID = "cus_ps_cancel_vertical"
        defer { CustomerPaymentOption.setDefaultPaymentMethod(nil, forCustomer: customerID) }
        let cardA = STPPaymentMethod._testCard()
        CustomerPaymentOption.setDefaultPaymentMethod(.stripeId(cardA.stripeId), forCustomer: customerID)
        var config = PaymentSheet.Configuration._testValue_MostPermissive(isApplePayEnabled: true)
        config.customer = .init(id: customerID, ephemeralKeySecret: "ek_test")
        let loadResult = makeLoadResult(savedPaymentMethods: [cardA])
        let sheet = PaymentSheet(paymentIntentClientSecret: "pi_123_secret_456", configuration: config)
        let vc = PaymentSheetVerticalViewController(configuration: config, loadResult: loadResult, isFlowController: false, analyticsHelper: ._testValue(), previousPaymentOption: nil)
        vc.loadViewIfNeeded()
        sheet.persistedSelectionSnapshot = .capture(paymentOption: nil, customerID: customerID, savedPaymentMethods: [cardA])

        // When the user selects Apple Pay (which persists it as the default)...
        vc.didTapPaymentMethod(.applePay)
        XCTAssertEqual(CustomerPaymentOption.localDefaultPaymentMethod(for: customerID), .applePay)

        // ...and then cancels the sheet
        sheet.paymentSheetViewControllerDidCancel(vc)

        // Then the persisted default reverts to card A
        XCTAssertEqual(CustomerPaymentOption.localDefaultPaymentMethod(for: customerID), .stripeId(cardA.stripeId))

        // And re-presenting derives the original selection
        let freshVC = PaymentSheetVerticalViewController(configuration: config, loadResult: loadResult, isFlowController: false, analyticsHelper: ._testValue(), previousPaymentOption: nil)
        freshVC.loadViewIfNeeded()
        guard case .saved(let selected) = freshVC.paymentMethodListViewController?.currentSelection else {
            return XCTFail("Expected a saved payment method to be selected on re-presentation")
        }
        XCTAssertEqual(selected.stripeId, cardA.stripeId)
    }

    func testHorizontalCancel_revertsPersistedDefault() throws {
        // Given card A is the persisted default when the sheet is presented
        let customerID = "cus_ps_cancel_horizontal"
        defer { CustomerPaymentOption.setDefaultPaymentMethod(nil, forCustomer: customerID) }
        let cardA = STPPaymentMethod._testCard()
        let bank = STPPaymentMethod._testUSBankAccount()
        CustomerPaymentOption.setDefaultPaymentMethod(.stripeId(cardA.stripeId), forCustomer: customerID)
        let config = makeConfiguration(customerID: customerID)
        let loadResult = makeLoadResult(savedPaymentMethods: [cardA, bank])
        let sheet = PaymentSheet(paymentIntentClientSecret: "pi_123_secret_456", configuration: config)
        let vc = PaymentSheetViewController(configuration: config, loadResult: loadResult, analyticsHelper: ._testValue(), delegate: sheet)
        vc.loadViewIfNeeded()
        sheet.persistedSelectionSnapshot = .capture(paymentOption: nil, customerID: customerID, savedPaymentMethods: [cardA, bank])

        // When the user taps the bank tile (which persists it as the default)...
        let savedOptions = vc.savedPaymentOptionsViewController
        savedOptions.loadViewIfNeeded()
        let bankIndex = try XCTUnwrap(savedOptions.viewModels.firstIndex(where: { $0 == CustomerPaymentOption.stripeId(bank.stripeId) }))
        let dummyCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        savedOptions.collectionView(dummyCollectionView, didSelectItemAt: IndexPath(item: bankIndex, section: 0))
        XCTAssertEqual(CustomerPaymentOption.localDefaultPaymentMethod(for: customerID), .stripeId(bank.stripeId))

        // ...and then cancels the sheet
        sheet.paymentSheetViewControllerDidCancel(vc)

        // Then the persisted default reverts to card A
        XCTAssertEqual(CustomerPaymentOption.localDefaultPaymentMethod(for: customerID), .stripeId(cardA.stripeId))
    }

    @MainActor
    func testVerticalDeleteSelectedPM_thenCancel_defaultNotResurrected() throws {
        // Given card A is the persisted default and selected when the sheet is presented
        let customerID = "cus_ps_cancel_delete"
        defer { CustomerPaymentOption.setDefaultPaymentMethod(nil, forCustomer: customerID) }
        let cardA = STPPaymentMethod._testCard()
        let bank = STPPaymentMethod._testUSBankAccount()
        CustomerPaymentOption.setDefaultPaymentMethod(.stripeId(cardA.stripeId), forCustomer: customerID)
        let config = makeConfiguration(customerID: customerID)
        let loadResult = makeLoadResult(savedPaymentMethods: [cardA, bank])
        let sheet = PaymentSheet(paymentIntentClientSecret: "pi_123_secret_456", configuration: config)
        let vc = PaymentSheetVerticalViewController(configuration: config, loadResult: loadResult, isFlowController: false, analyticsHelper: ._testValue(), previousPaymentOption: nil)
        vc.loadViewIfNeeded()
        sheet.persistedSelectionSnapshot = .capture(paymentOption: nil, customerID: customerID, savedPaymentMethods: [cardA, bank])

        // When card A is deleted in the manage screen (in production, detach also clears the
        // persisted default — covered by SavedPaymentMethodManagerTests)...
        let manageVC = VerticalSavedPaymentMethodsViewController(
            configuration: config,
            intent: ._testValue(),
            selectedPaymentMethod: cardA,
            paymentMethods: [cardA, bank],
            elementsSession: ._testCardValue(),
            analyticsHelper: ._testValue(),
            defaultPaymentMethod: nil
        )
        vc.didComplete(viewController: manageVC, with: bank, latestPaymentMethods: [bank], didTapToDismiss: false, defaultPaymentMethod: nil)

        // ...and the user then cancels
        sheet.paymentSheetViewControllerDidCancel(vc)

        // Then the deleted payment method must not be resurrected as the persisted default
        XCTAssertNotEqual(CustomerPaymentOption.localDefaultPaymentMethod(for: customerID), .stripeId(cardA.stripeId))
    }
}
