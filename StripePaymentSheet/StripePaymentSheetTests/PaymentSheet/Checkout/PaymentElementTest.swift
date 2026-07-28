//
//  PaymentElementTest.swift
//  StripePaymentSheetTests
//
//  Created by Yuki Tokuhiro on 7/15/26.
//

import OHHTTPStubs
@testable @_spi(STP) import StripeCore
@testable @_spi(STP) import StripePayments
@testable @_spi(STP) import StripePaymentSheet
@testable @_spi(STP) import StripePaymentsTestUtils
@testable @_spi(STP) import StripeUICore
import XCTest

@MainActor
final class PaymentElementTest: XCTestCase {

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        CustomerPaymentOption.setDefaultPaymentMethod(nil, forCustomer: nil)
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        let expectation = expectation(description: "Load specs")
        AddressSpecProvider.shared.loadAddressSpecs {
            FormSpecProvider.shared.load { _ in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }

    func testConfigurationSetsCheckoutDefaultBillingDetails() async throws {
        // Given Checkout billing defaults
        var checkoutConfiguration = Checkout.Configuration(clientSecret: "cs_test_123_secret_abc")
        var billingDetails = Checkout.Configuration.Defaults.BillingDetails()
        billingDetails.name = "Jane Doe"
        billingDetails.address = .init(
            country: "US",
            line1: "123 Main St",
            line2: "Apt 4",
            city: "San Francisco",
            state: "CA",
            postalCode: "94105"
        )
        checkoutConfiguration.defaults.billingDetails = billingDetails

        // When Checkout creates PaymentElement
        let checkout = try await Checkout(
            configuration: CheckoutTestHelpers.makeConfiguration(configuration: checkoutConfiguration)
        )
        let paymentElement = checkout.getPaymentElement()
        let paymentSheetConfiguration = paymentElement.paymentSheetFlowController.configuration
        let embeddedConfiguration = paymentElement.embeddedPaymentElement.configuration

        // Then both configurations receive the same default billing details
        XCTAssertEqual(paymentSheetConfiguration.defaultBillingDetails.name, "Jane Doe")
        XCTAssertEqual(paymentSheetConfiguration.defaultBillingDetails.address.country, "US")
        XCTAssertEqual(paymentSheetConfiguration.defaultBillingDetails.address.line1, "123 Main St")
        XCTAssertEqual(paymentSheetConfiguration.defaultBillingDetails.address.line2, "Apt 4")
        XCTAssertEqual(paymentSheetConfiguration.defaultBillingDetails.address.city, "San Francisco")
        XCTAssertEqual(paymentSheetConfiguration.defaultBillingDetails.address.state, "CA")
        XCTAssertEqual(paymentSheetConfiguration.defaultBillingDetails.address.postalCode, "94105")

        XCTAssertEqual(embeddedConfiguration.defaultBillingDetails, paymentSheetConfiguration.defaultBillingDetails)
    }

    func testConfigurationSetsCheckoutDefaultShippingDetails() async throws {
        // Given Checkout shipping defaults
        var checkoutConfiguration = Checkout.Configuration(clientSecret: "cs_test_123_secret_abc")
        var shippingDetails = Checkout.Configuration.Defaults.ShippingDetails()
        shippingDetails.name = "Jane Doe"
        shippingDetails.address = .init(
            country: "US",
            line1: "123 Main St",
            line2: "Apt 4",
            city: "San Francisco",
            state: "CA",
            postalCode: "94105"
        )
        checkoutConfiguration.defaults.shippingDetails = shippingDetails

        // When Checkout creates PaymentElement
        let checkout = try await Checkout(
            configuration: CheckoutTestHelpers.makeConfiguration(configuration: checkoutConfiguration)
        )
        let paymentElement = checkout.getPaymentElement()
        let paymentSheetShipping = paymentElement.paymentSheetFlowController.configuration.shippingDetails()
        let embeddedShipping = paymentElement.embeddedPaymentElement.configuration.shippingDetails()

        // Then both configurations receive the same default shipping details
        XCTAssertEqual(paymentSheetShipping?.name, "Jane Doe")
        XCTAssertEqual(paymentSheetShipping?.address.country, "US")
        XCTAssertEqual(paymentSheetShipping?.address.line1, "123 Main St")
        XCTAssertEqual(paymentSheetShipping?.address.line2, "Apt 4")
        XCTAssertEqual(paymentSheetShipping?.address.city, "San Francisco")
        XCTAssertEqual(paymentSheetShipping?.address.state, "CA")
        XCTAssertEqual(paymentSheetShipping?.address.postalCode, "94105")

        XCTAssertEqual(embeddedShipping?.name, paymentSheetShipping?.name)
        XCTAssertEqual(embeddedShipping?.address.country, paymentSheetShipping?.address.country)
        XCTAssertEqual(embeddedShipping?.address.line1, paymentSheetShipping?.address.line1)
        XCTAssertEqual(embeddedShipping?.address.line2, paymentSheetShipping?.address.line2)
        XCTAssertEqual(embeddedShipping?.address.city, paymentSheetShipping?.address.city)
        XCTAssertEqual(embeddedShipping?.address.state, paymentSheetShipping?.address.state)
        XCTAssertEqual(embeddedShipping?.address.postalCode, paymentSheetShipping?.address.postalCode)
    }

    func testConfigurationSetsFullBillingAddressCollectionWhenCheckoutRequiresBillingAddress() async throws {
        // Given automatic billing address collection in PaymentElement
        let checkoutConfiguration = Checkout.Configuration(clientSecret: "cs_test_123_secret_abc")
        let session = CheckoutTestHelpers.makeOpenSession(billingAddressCollection: "required")

        // When Checkout requires billing address collection
        let checkout = try await Checkout(
            configuration: CheckoutTestHelpers.makeConfiguration(
                apiResponse: session,
                configuration: checkoutConfiguration
            )
        )
        let paymentElement = checkout.getPaymentElement()

        // Then both configurations collect full billing address
        XCTAssertEqual(paymentElement.paymentSheetFlowController.configuration.billingDetailsCollectionConfiguration.address, .full)
        XCTAssertEqual(paymentElement.embeddedPaymentElement.configuration.billingDetailsCollectionConfiguration.address, .full)
    }

    func testConfigurationPreservesFullBillingAddressCollectionWhenCheckoutBillingAddressCollectionIsAutomatic() async throws {
        // Given full billing address collection in PaymentElement
        var checkoutConfiguration = Checkout.Configuration(clientSecret: "cs_test_123_secret_abc")
        checkoutConfiguration.paymentElement.billingDetailsCollectionConfiguration.address = .full

        // When Checkout uses automatic billing address collection
        let checkout = try await Checkout(
            configuration: CheckoutTestHelpers.makeConfiguration(configuration: checkoutConfiguration)
        )
        let paymentElement = checkout.getPaymentElement()

        // Then both configurations preserve full billing address collection
        XCTAssertEqual(paymentElement.paymentSheetFlowController.configuration.billingDetailsCollectionConfiguration.address, .full)
        XCTAssertEqual(paymentElement.embeddedPaymentElement.configuration.billingDetailsCollectionConfiguration.address, .full)
    }

    func testCheckoutSessionUpdatePreservesFlowControllerPaymentOption() async throws {
        // Given a Checkout PaymentElement with PayNow available in the real FlowController sheet UI...
        var configuration = Checkout.Configuration(clientSecret: "cs_test_123_secret_abc")
        configuration.paymentElement.paymentMethodLayout = .vertical
        let checkout = try await Checkout(
            configuration: CheckoutTestHelpers.makeConfiguration(
                apiResponse: Self.makeOpenSession(paymentMethodTypes: ["card", "paynow"]),
                configuration: configuration
            )
        )
        let paymentElement = checkout.getPaymentElement()
        let viewController = try XCTUnwrap(
            paymentElement.paymentSheetFlowController.viewController as? PaymentSheetVerticalViewController
        )
        let paymentMethodListViewController = try XCTUnwrap(viewController.paymentMethodListViewController)
        XCTAssertNil(paymentMethodListViewController.currentSelection)
        XCTAssertNil(checkout.session.paymentOption)

        // When the customer selects PayNow in FlowController and Checkout commits a session update...
        let payNowRowButton = try XCTUnwrap(
            paymentMethodListViewController.rowButtons.first { $0.accessibilityIdentifier == "PayNow" },
            "Available rows: \(paymentMethodListViewController.rowButtons.compactMap(\.accessibilityIdentifier))"
        )
        paymentMethodListViewController.didTap(
            rowButton: payNowRowButton,
            selection: .new(paymentMethodType: .stripe(.paynow))
        )
        paymentElement.paymentSheetFlowController.updatePaymentOption()
        XCTAssertEqual(checkout.session.paymentOption?.label, "PayNow")
        XCTAssertEqual(checkout.session.paymentOption?.paymentMethodType, "paynow")

        let completedSession = PaymentPagesAPIResponse.decodedObject(fromAPIResponse: {
            var json = Self.openSessionJSON(paymentMethodTypes: ["card", "paynow"])
            json["status"] = "complete"
            json["payment_status"] = "paid"
            return json
        }())!
        try await checkout.commitSession(completedSession)

        // Then the Checkout payment option still reflects FlowController's selected payment option.
        XCTAssertEqual(checkout.session.paymentOption?.label, "PayNow")
        XCTAssertEqual(checkout.session.paymentOption?.paymentMethodType, "paynow")
    }

    func testSelectingSavedPaymentMethodInEmbeddedViewSyncsBillingAddress() async throws {
        // Given an unselected saved payment method and a Checkout Session using billing address for automatic tax
        let didSelectPaymentOption = expectation(description: "Saved payment method selection completes")
        let fixture = try await makeSavedPaymentMethodSelectionFixture(
            didSelectPaymentOption: {
                didSelectPaymentOption.fulfill()
            }
        )
        let tappedPaymentMethod = try XCTUnwrap(fixture.savedPaymentMethodRow.type.savedPaymentMethod)

        // When the customer selects the saved payment method directly, without opening a sheet
        fixture.embeddedPaymentElement.embeddedPaymentMethodsView.didTap(
            rowButton: fixture.savedPaymentMethodRow
        )

        // Then the row shows a loader and Checkout keeps the previous selection while billing syncs
        XCTAssertFalse(fixture.embeddedPaymentElement.embeddedPaymentMethodsView.isUserInteractionEnabled)
        XCTAssertTrue(fixture.savedPaymentMethodRow.isLoading)
        XCTAssertNil(fixture.checkout.session.paymentOption)
        XCTAssertNil(CustomerPaymentOption.localDefaultPaymentMethod(for: nil))
        await fulfillment(of: [didSelectPaymentOption])

        // ...and the full address is synced before selection completes
        XCTAssertTrue(fixture.embeddedPaymentElement.embeddedPaymentMethodsView.isUserInteractionEnabled)
        XCTAssertEqual(fixture.checkout.session.paymentOption?.label, "•••• 4242")
        let selectedRow = try XCTUnwrap(
            fixture.embeddedPaymentElement.embeddedPaymentMethodsView.selectedRowButton
        )
        XCTAssertFalse(selectedRow.isLoading)
        XCTAssertEqual(
            selectedRow.type.savedPaymentMethod?.stripeId,
            tappedPaymentMethod.stripeId
        )
        XCTAssertEqual(
            CustomerPaymentOption.localDefaultPaymentMethod(for: nil),
            .stripeId(tappedPaymentMethod.stripeId)
        )
        let requests = fixture.requestRecorder.requests
        XCTAssertEqual(requests.map(\.kind), [.initSession, .updateSession])
        let updateRequest = try XCTUnwrap(requests.last)
        XCTAssertEqual(updateRequest.params["tax_region[country]"], "US")
        XCTAssertEqual(updateRequest.params["tax_region[line1]"], "123 Main St")
        XCTAssertEqual(updateRequest.params["tax_region[city]"], "San Francisco")
        XCTAssertEqual(updateRequest.params["tax_region[state]"], "CA")
        XCTAssertEqual(updateRequest.params["tax_region[postal_code]"], "94105")
    }

    func testSelectingSavedPaymentMethodInEmbeddedViewWithoutBillingTaxCompletesSynchronously() async throws {
        // Given a Checkout Session that doesn't calculate tax from billing address
        var didSelectPaymentOption = false
        let fixture = try await makeSavedPaymentMethodSelectionFixture(
            automaticTaxFromBilling: false,
            didSelectPaymentOption: {
                didSelectPaymentOption = true
            }
        )

        // When the customer selects a saved payment method
        fixture.embeddedPaymentElement.embeddedPaymentMethodsView.didTap(
            rowButton: fixture.savedPaymentMethodRow
        )

        // Then selection completes synchronously without an unnecessary update
        XCTAssertTrue(didSelectPaymentOption)
        XCTAssertEqual(fixture.requestRecorder.requests.map(\.kind), [.initSession])
        let savedPaymentMethod = try XCTUnwrap(fixture.savedPaymentMethodRow.type.savedPaymentMethod)
        XCTAssertEqual(
            CustomerPaymentOption.localDefaultPaymentMethod(for: nil),
            .stripeId(savedPaymentMethod.stripeId)
        )
    }

    func testSelectingSavedPaymentMethodInEmbeddedViewRevertsSelectionAndDisplaysBillingSyncError() async throws {
        // Given PayNow is selected and the Checkout billing address update will fail
        var didSelectPaymentOption = false
        let fixture = try await makeSavedPaymentMethodSelectionFixture(
            paymentMethodTypes: ["card", "paynow"],
            updateStatusCode: 500,
            didSelectPaymentOption: {
                didSelectPaymentOption = true
            }
        )
        let payNowRow = try XCTUnwrap(
            fixture.embeddedPaymentElement.embeddedPaymentMethodsView.rowButtons.first {
                $0.type == .new(paymentMethodType: .stripe(.paynow))
            }
        )
        fixture.embeddedPaymentElement.presentingViewController = UIViewController()
        fixture.embeddedPaymentElement.embeddedPaymentMethodsView.didTap(
            rowButton: payNowRow
        )
        fixture.embeddedPaymentElement._test_paymentOption = .new(
            confirmParams: IntentConfirmParams(type: .stripe(.paynow))
        )
        fixture.embeddedPaymentElement.informDelegateIfPaymentOptionUpdated()
        XCTAssertEqual(fixture.checkout.session.paymentOption?.paymentMethodType, "paynow")

        // When the customer selects a saved payment method
        fixture.embeddedPaymentElement.embeddedPaymentMethodsView.didTap(
            rowButton: fixture.savedPaymentMethodRow
        )
        try await waitUntil {
            fixture.embeddedPaymentElement.embeddedPaymentMethodsView._test_displayedErrorMessage != nil
        }

        // Then the previous selection is restored and the error is displayed under EPE
        XCTAssertFalse(didSelectPaymentOption)
        XCTAssertFalse(fixture.savedPaymentMethodRow.isLoading)
        XCTAssertTrue(fixture.embeddedPaymentElement.embeddedPaymentMethodsView.isUserInteractionEnabled)
        XCTAssertEqual(
            fixture.embeddedPaymentElement.embeddedPaymentMethodsView.selectedRowButton?.type,
            .new(paymentMethodType: .stripe(.paynow))
        )
        XCTAssertEqual(fixture.checkout.session.paymentOption?.paymentMethodType, "paynow")
        XCTAssertEqual(fixture.checkout.session.paymentOption?.label, "PayNow")
        XCTAssertNil(CustomerPaymentOption.localDefaultPaymentMethod(for: nil))
        XCTAssertFalse(
            try XCTUnwrap(
                fixture.embeddedPaymentElement.embeddedPaymentMethodsView._test_displayedErrorMessage
            ).isEmpty
        )
        XCTAssertEqual(
            fixture.requestRecorder.requests.map(\.kind),
            [.initSession, .updateSession]
        )
    }

    func testCheckoutAndPaymentElementDoNotRetainEachOther() async throws {
        weak var weakCheckout: Checkout?
        weak var weakPaymentElement: PaymentElement?
        weak var weakFlowController: PaymentSheet.FlowController?
        weak var weakEmbeddedPaymentElement: EmbeddedPaymentElement?

        do {
            let checkout = try await Checkout(
                configuration: CheckoutTestHelpers.makeConfiguration(
                    apiResponse: Self.makeOpenSession(paymentMethodTypes: ["card"])
                )
            )
            let paymentElement = checkout.getPaymentElement()

            weakCheckout = checkout
            weakPaymentElement = paymentElement
            weakFlowController = paymentElement.paymentSheetFlowController
            weakEmbeddedPaymentElement = paymentElement.embeddedPaymentElement
        }

        XCTAssertNil(weakCheckout)
        XCTAssertNil(weakPaymentElement)
        XCTAssertNil(weakFlowController)
        XCTAssertNil(weakEmbeddedPaymentElement)
    }

    private static func makeOpenSession(paymentMethodTypes: [String]) -> PaymentPagesAPIResponse {
        return PaymentPagesAPIResponse.decodedObject(
            fromAPIResponse: openSessionJSON(paymentMethodTypes: paymentMethodTypes)
        )!
    }

    private static func openSessionJSON(paymentMethodTypes: [String]) -> [AnyHashable: Any] {
        var elementsSessionJSON = CheckoutTestHelpers.minimalElementsSessionJSON
        elementsSessionJSON["payment_method_preference"] = [
            "ordered_payment_method_types": paymentMethodTypes,
        ]

        var json = CheckoutTestHelpers.openSessionJSON
        json["payment_method_types"] = paymentMethodTypes
        json["elements_session"] = elementsSessionJSON
        json["total_summary"] = [
            "subtotal": 1099,
            "total": 1099,
            "due": 1099,
        ]
        return json
    }

    private func makeSavedPaymentMethodSelectionFixture(
        automaticTaxFromBilling: Bool = true,
        paymentMethodTypes: [String] = ["card"],
        updateStatusCode: Int32 = 200,
        didSelectPaymentOption: @escaping () -> Void
    ) async throws -> (
        checkout: Checkout,
        embeddedPaymentElement: EmbeddedPaymentElement,
        savedPaymentMethodRow: RowButton,
        requestRecorder: CheckoutSessionRequestRecorder
    ) {
        let requestRecorder = CheckoutSessionRequestRecorder()
        let sessionJSON = Self.openSessionJSONWithSavedPaymentMethod(
            automaticTaxFromBilling: automaticTaxFromBilling,
            paymentMethodTypes: paymentMethodTypes
        )
        CheckoutTestHelpers.stubCheckoutSessionRequests(
            sessionId: "cs_test_123",
            requestRecorder: requestRecorder,
            sessionJSON: { sessionJSON },
            updateStatusCode: updateStatusCode
        )
        CustomerPaymentOption.setDefaultPaymentMethod(nil, forCustomer: nil)

        var configuration = Checkout.Configuration(clientSecret: "cs_test_123_secret_abc")
        configuration.apiClient = STPAPIClient(publishableKey: "pk_test_123")
        configuration.paymentElement.rowSelectionBehavior = .immediateAction(
            didSelectPaymentOption: didSelectPaymentOption
        )

        let checkout = try await Checkout(configuration: configuration)
        let embeddedPaymentElement = checkout.getPaymentElement().embeddedPaymentElement
        let savedPaymentMethodRow = try XCTUnwrap(
            embeddedPaymentElement.embeddedPaymentMethodsView.rowButtons.first {
                $0.type.isSaved
            }
        )
        embeddedPaymentElement.clearPaymentOption()

        return (checkout, embeddedPaymentElement, savedPaymentMethodRow, requestRecorder)
    }

    private static func openSessionJSONWithSavedPaymentMethod(
        automaticTaxFromBilling: Bool,
        paymentMethodTypes: [String]
    ) -> [AnyHashable: Any] {
        var savedPaymentMethod = STPPaymentMethod._testCardJSON
        savedPaymentMethod["billing_details"] = [
            "address": [
                "country": "US",
                "line1": "123 Main St",
                "city": "San Francisco",
                "state": "CA",
                "postal_code": "94105",
            ],
        ]

        var elementsSession = CheckoutTestHelpers.minimalElementsSessionJSON
        elementsSession["payment_method_preference"] = [
            "ordered_payment_method_types": paymentMethodTypes,
        ]
        elementsSession["customer"] = [
            "payment_methods": [savedPaymentMethod],
            "customer_session": [
                "id": "cuss_test_123",
                "livemode": false,
                "api_key": "ek_test_123",
                "api_key_expiry": 12345,
                "customer": "cus_test_123",
                "components": [
                    "mobile_payment_element": [
                        "enabled": true,
                        "features": [
                            "payment_method_save": "enabled",
                            "payment_method_remove": "enabled",
                        ],
                    ],
                    "customer_sheet": [
                        "enabled": false,
                    ],
                ],
            ],
        ]

        var json = openSessionJSON(paymentMethodTypes: paymentMethodTypes)
        json["elements_session"] = elementsSession
        if automaticTaxFromBilling {
            json["tax_context"] = [
                "automatic_tax_enabled": true,
                "automatic_tax_address_source": "session.billing",
            ]
        }
        return json
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Condition not met within \(timeout) seconds", file: file, line: line)
                throw PaymentElementTestTimeoutError()
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

private struct PaymentElementTestTimeoutError: Error {}
