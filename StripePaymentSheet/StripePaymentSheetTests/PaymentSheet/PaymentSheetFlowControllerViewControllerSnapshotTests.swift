//
//  PaymentSheetFlowControllerViewControllerSnapshotTests.swift
//  StripePaymentSheetTests
//
//  Created by Yuki Tokuhiro on 9/7/23.
//

@_spi(STP) import StripeCore
import StripeCoreTestUtils
@_spi(STP) @testable import StripePaymentSheet
@_spi(STP) @testable import StripeUICore

import XCTest

// @iOS26
final class PaymentSheetFlowControllerViewControllerSnapshotTests: STPSnapshotTestCase {
    func makeTestLoadResult(savedPaymentMethods: [STPPaymentMethod]) -> PaymentSheetLoader.LoadResult {
        return .init(
            intent: ._testValue(),
            elementsSession: ._testValue(paymentMethodTypes: ["card"], isLinkPassthroughModeEnabled: false),
            savedPaymentMethods: savedPaymentMethods,
            paymentMethodTypes: [.stripe(.card)],
            paymentMethodMessagingPromotionsHelper: ._testValue(),
            paymentMethodOrientation: .horizontal
        )
    }

    func testSavedScreen_card() {
        let sut = makeSavedCardSUT()
        sut.view.autosizeHeight(width: 375)
        STPSnapshotVerifyView(sut.view)
    }

    func testSavedScreen_cardRightToLeft() {
        let sut = makeSavedCardSUT()
        sut.view.forceRightToLeftLayout()
        sut.view.autosizeHeight(width: 375)
        XCTAssertEqual(sut.view.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        STPSnapshotVerifyView(sut.view)
    }

    func testSavedScreen_cardRightToLeftDynamicType() {
        let sut = makeSavedCardSUT()
        let traitHost = overrideTraits(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraLarge),
            for: sut
        )
        sut.view.forceRightToLeftLayout()
        sut.view.autosizeHeight(width: 375)

        XCTAssertEqual(sut.view.traitCollection.preferredContentSizeCategory, .accessibilityExtraExtraLarge)
        withExtendedLifetime(traitHost) {
            STPSnapshotVerifyView(sut.view)
        }
    }

    func testSavedScreen_cardRightToLeftLandscape() {
        let sut = makeSavedCardSUT()
        let traitHost = overrideTraits(
            UITraitCollection(traitsFrom: [
                UITraitCollection(horizontalSizeClass: .compact),
                UITraitCollection(verticalSizeClass: .compact),
            ]),
            for: sut
        )
        sut.view.forceRightToLeftLayout()
        sut.view.autosizeHeight(width: 844)

        XCTAssertEqual(sut.view.bounds.width, 844)
        XCTAssertEqual(sut.view.traitCollection.verticalSizeClass, .compact)
        withExtendedLifetime(traitHost) {
            STPSnapshotVerifyView(sut.view)
        }
    }

    func testSavedScreen_cardRightToLeftIPad() {
        let sut = makeSavedCardSUT()
        let traitHost = overrideTraits(
            UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceIdiom: .pad),
                UITraitCollection(horizontalSizeClass: .regular),
                UITraitCollection(verticalSizeClass: .regular),
            ]),
            for: sut
        )
        sut.view.forceRightToLeftLayout()
        sut.view.autosizeHeight(width: 1024)

        XCTAssertEqual(sut.view.bounds.width, 1024)
        XCTAssertEqual(sut.view.traitCollection.userInterfaceIdiom, .pad)
        withExtendedLifetime(traitHost) {
            STPSnapshotVerifyView(sut.view)
        }
    }

    func testSavedScreen_us_bank_account() {
        let paymentMethods = [
            STPPaymentMethod._testUSBankAccount(),
        ]
        let sut = PaymentSheetFlowControllerViewController(
            configuration: ._testValue_MostPermissive(isApplePayEnabled: false),
            loadResult: makeTestLoadResult(savedPaymentMethods: paymentMethods),
            analyticsHelper: ._testValue()
        )
        sut.view.autosizeHeight(width: 375)
        STPSnapshotVerifyView(sut.view)
    }

    func testSavedScreen_SEPA_debit() {
        let paymentMethods = [
            STPPaymentMethod._testSEPA(),
        ]
        let sut = PaymentSheetFlowControllerViewController(
            configuration: ._testValue_MostPermissive(isApplePayEnabled: false),
            loadResult: makeTestLoadResult(savedPaymentMethods: paymentMethods),
            analyticsHelper: ._testValue()
        )
        sut.view.autosizeHeight(width: 375)
        STPSnapshotVerifyView(sut.view)
    }

    func testSavedScreen_customCTA() {
        let paymentMethods = [
            STPPaymentMethod._testSEPA(),
        ]
        var configuration: PaymentSheet.Configuration = ._testValue_MostPermissive(isApplePayEnabled: false)
        configuration.primaryButtonLabel = "Submit"
        let sut = PaymentSheetFlowControllerViewController(
            configuration: configuration,
            loadResult: makeTestLoadResult(savedPaymentMethods: paymentMethods),
            analyticsHelper: ._testValue()
        )
        sut.view.autosizeHeight(width: 375)
        STPSnapshotVerifyView(sut.view)
    }

    func testNewScreen_customCTA() {
        let expectation = expectation(description: "Load address specs")
        AddressSpecProvider.shared.loadAddressSpecs {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        var configuration: PaymentSheet.Configuration = ._testValue_MostPermissive(isApplePayEnabled: false)
        configuration.primaryButtonLabel = "Submit"
        let sut = PaymentSheetFlowControllerViewController(
            configuration: configuration,
            loadResult: makeTestLoadResult(savedPaymentMethods: []),
            analyticsHelper: ._testValue()
        )
        sut.view.autosizeHeight(width: 375)
        STPSnapshotVerifyView(sut.view)
    }

    func testDirectToCardScan() {
        let sut = makeDirectToCardScanSUT()
        sut.view.autosizeHeight(width: 375)
        STPSnapshotVerifyView(sut.view)
    }

    func testDirectToCardScanRightToLeft() throws {
        let sut = makeDirectToCardScanSUT()
        sut.view.forceRightToLeftLayout()
        sut.view.autosizeHeight(width: 375)

        let cardScanningView = try XCTUnwrap(findSubview(of: CardScanningView.self, in: sut.view))
        let closeButton = try XCTUnwrap(findSubview(of: CircularButton.self, in: cardScanningView))
        XCTAssertLessThan(closeButton.frame.midX, cardScanningView.bounds.midX)
        STPSnapshotVerifyView(sut.view)
    }

    private func makeDirectToCardScanSUT() -> PaymentSheetFlowControllerViewController {
        let expectation = expectation(description: "Load address specs")
        AddressSpecProvider.shared.loadAddressSpecs {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        var configuration: PaymentSheet.Configuration = PaymentSheet.Configuration()
        configuration.returnURL = "https://foo.com"
        configuration.opensCardScannerAutomatically = true
        configuration.appearance.applyLiquidGlassIfPossible()

        let loadResult = PaymentSheetLoader.LoadResult(
            intent: ._testValue(),
            elementsSession: ._testValue(
                paymentMethodTypes: ["card"],
                isLinkPassthroughModeEnabled: false
            ),
            savedPaymentMethods: [],
            paymentMethodTypes: [.stripe(.card)],
            paymentMethodMessagingPromotionsHelper: ._testValue(),
            paymentMethodOrientation: .horizontal
        )

        let sut = PaymentSheetFlowControllerViewController(
            configuration: configuration,
            loadResult: loadResult,
            analyticsHelper: ._testValue()
        )
        return sut
    }

    private func makeSavedCardSUT() -> PaymentSheetFlowControllerViewController {
        return PaymentSheetFlowControllerViewController(
            configuration: ._testValue_MostPermissive(isApplePayEnabled: false),
            loadResult: makeTestLoadResult(savedPaymentMethods: [STPPaymentMethod._testCard()]),
            analyticsHelper: ._testValue()
        )
    }

    private func overrideTraits(
        _ traits: UITraitCollection,
        for sut: UIViewController
    ) -> UIViewController {
        let host = UIViewController()
        host.addChild(sut)
        host.setOverrideTraitCollection(traits, forChild: sut)
        sut.didMove(toParent: host)
        return host
    }

    private func findSubview<T: UIView>(of type: T.Type, in view: UIView) -> T? {
        if let match = view as? T {
            return match
        }
        return view.subviews.lazy.compactMap { self.findSubview(of: type, in: $0) }.first
    }
}
