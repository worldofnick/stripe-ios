//
//  RowButtonTests.swift
//  StripePaymentSheetTests
//

import UIKit
import XCTest

@_spi(STP) @testable import StripePaymentSheet
@testable @_spi(STP) import StripeUICore

final class RowButtonTests: XCTestCase {
    func testLoadingStatePreservesKeyContentAlpha() {
        let rowButton = SavedPaymentMethodRowButton(
            paymentMethod: STPPaymentMethod._testCard(),
            appearance: .default
        ).rowButton
        rowButton.setKeyContent(alpha: 0.5)

        rowButton.setLoading(true, animated: false)
        XCTAssertEqual(rowButton.imageView.alpha, 0)

        rowButton.setLoading(false, animated: false)
        XCTAssertEqual(rowButton.imageView.alpha, 0.5)
    }

    func testTrailingLoadingStatePreservesImage() throws {
        let rowButton = SavedPaymentMethodRowButton(
            paymentMethod: STPPaymentMethod._testCard(),
            appearance: .default
        ).rowButton
        rowButton.frame = CGRect(x: 0, y: 0, width: 320, height: 64)

        rowButton.setLoading(true, style: .trailing, animated: false)
        rowButton.layoutIfNeeded()

        let spinner = try XCTUnwrap(rowButton.subviews.first { $0 is ActivityIndicator })
        XCTAssertEqual(rowButton.imageView.alpha, 1)
        XCTAssertEqual(spinner.frame.maxX, rowButton.bounds.maxX - 16)
    }

    func testRightToLeftVoiceOverTraversalReadsPrimaryActionBeforeTrailingAccessory() throws {
        var appearance = PaymentSheet.Appearance()
        appearance.embeddedPaymentElement.row.style = .floatingButton
        let paymentMethod = STPPaymentMethod._testCard()
        let embeddedView = EmbeddedPaymentMethodsView(
            initialSelection: .saved(paymentMethod: paymentMethod),
            paymentMethodTypes: [.stripe(.card)],
            savedPaymentMethod: paymentMethod,
            appearance: appearance,
            shouldShowApplePay: false,
            shouldShowLink: false,
            savedPaymentMethodAccessoryType: .viewMoreChevron,
            mandateProvider: MockMandateProvider()
        )

        let rootViewController = UIViewController()
        let childViewController = UIViewController()
        childViewController.view = embeddedView
        rootViewController.addChild(childViewController)
        rootViewController.setOverrideTraitCollection(
            UITraitCollection(layoutDirection: .rightToLeft),
            forChild: childViewController
        )
        rootViewController.view.addSubview(embeddedView)
        childViewController.didMove(toParent: rootViewController)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 1_000))
        window.rootViewController = rootViewController
        window.isHidden = false
        embeddedView.autosizeHeight(width: 320)

        let rowButton = try XCTUnwrap(embeddedView.rowButtons.first)
        let accessory = try XCTUnwrap(rowButton.accessoryView)

        let accessibilityElements = try XCTUnwrap(rowButton.accessibilityElements as? [UIView])
        XCTAssertEqual(accessibilityElements[0].accessibilityIdentifier, rowButton.accessibilityIdentifier)
        XCTAssertTrue(accessibilityElements[1] === accessory)
        XCTAssertLessThan(
            accessory.convert(accessory.bounds, to: rowButton).midX,
            rowButton.bounds.midX
        )
        withExtendedLifetime(window) {}
    }

    func testFlatWithDisclosureUsesRightToLeftFlippableDefaultChevron() {
        var appearance = PaymentSheet.Appearance()
        appearance.embeddedPaymentElement.row.style = .flatWithDisclosure
        let rowButton = RowButton.makeForPaymentMethodType(
            paymentMethodType: .stripe(.card),
            hasSavedCard: false,
            promotionsHelper: nil,
            appearance: appearance,
            shouldAnimateOnPress: false,
            isEmbedded: true,
            didTap: { _ in }
        )

        let flippableImages = rowButton.descendantImageViews.compactMap(\.image)
            .filter(\.flipsForRightToLeftLayoutDirection)
        XCTAssertEqual(flippableImages.count, 1)
    }

    func testRowButtonForPaymentMethodType_usesPaymentMethodMessagingSublabelWhenInTreatment() {
        let promotionsHelper = PaymentMethodMessagingPromotionsHelper._testValueInTreatment()
        let rowButton = RowButton.makeForPaymentMethodType(
            paymentMethodType: .stripe(.affirm),
            currency: "USD",
            hasSavedCard: false,
            promotionsHelper: promotionsHelper,
            appearance: .default,
            shouldAnimateOnPress: false,
            didTap: { _ in }
        )

        XCTAssert(rowButton.sublabel is RowButton.PaymentMethodMessagingSublabelView)
    }
}

private extension UIView {
    var descendantImageViews: [UIImageView] {
        subviews.flatMap { view in
            (view as? UIImageView).map { [$0] } ?? view.descendantImageViews
        }
    }
}
