//
//  RowButtonTests.swift
//  StripePaymentSheetTests
//

import StripeCoreTestUtils
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
        let accessory = UIButton(type: .system)
        accessory.setTitle("Details", for: .normal)
        accessory.isAccessibilityElement = true
        accessory.accessibilityIdentifier = "row_accessory"

        var appearance = PaymentSheet.Appearance()
        appearance.embeddedPaymentElement.row.style = .floatingButton
        let rowButton = RowButton.makeForPaymentMethodType(
            paymentMethodType: .stripe(.card),
            hasSavedCard: false,
            accessoryView: accessory,
            promotionsHelper: nil,
            appearance: appearance,
            shouldAnimateOnPress: false,
            isEmbedded: true,
            didTap: { _ in }
        )
        rowButton.frame = CGRect(x: 0, y: 0, width: 320, height: 64)
        rowButton.forceRightToLeftLayout()
        rowButton.layoutIfNeeded()

        let accessibilityElements = try XCTUnwrap(rowButton.accessibilityElements as? [UIView])
        XCTAssertEqual(
            accessibilityElements.compactMap(\.accessibilityIdentifier),
            [rowButton.accessibilityIdentifier, "row_accessory"]
        )
        XCTAssertLessThan(
            accessory.convert(accessory.bounds, to: rowButton).midX,
            rowButton.bounds.midX
        )
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
