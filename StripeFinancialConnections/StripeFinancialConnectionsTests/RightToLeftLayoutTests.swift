//
//  RightToLeftLayoutTests.swift
//  StripeFinancialConnectionsTests
//

@_spi(STP) import StripeCoreTestUtils
@testable @_spi(STP) import StripeFinancialConnections
import XCTest

final class RightToLeftLayoutTests: XCTestCase {
    func testNavigationBackImageFlipsForRightToLeftLayoutDirection() throws {
        // Given
        let navigationController = FinancialConnectionsNavigationController(
            rootViewController: UIViewController()
        )

        // When
        navigationController.configureAppearanceForNative()

        // Then
        let backImage = try XCTUnwrap(navigationController.navigationBar.standardAppearance.backIndicatorImage)
        XCTAssertTrue(backImage.flipsForRightToLeftLayoutDirection)
    }

    func testExitImageFlipsForRightToLeftLayoutDirection() throws {
        // Given
        let iconView = RoundedIconView(
            image: .image(.panel_arrow_right),
            style: .circle,
            appearance: .stripe
        )

        // When
        let imageView = try XCTUnwrap(iconView.subviews.first as? UIImageView)

        // Then
        XCTAssertTrue(try XCTUnwrap(imageView.image).flipsForRightToLeftLayoutDirection)
    }

    func testPaneTitleAlignsWithRightToLeftInterfaceDirection() throws {
        // Given
        let headerView = PaneLayoutView.createHeaderView(
            iconView: nil,
            title: "Select bank"
        )
        headerView.forceRightToLeftLayout()

        // When
        headerView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        headerView.layoutIfNeeded()
        let attributedTextView = try XCTUnwrap(headerView.firstSubview(of: AttributedTextView.self))
        attributedTextView.setNeedsLayout()
        attributedTextView.layoutIfNeeded()

        // Then
        XCTAssertEqual(attributedTextView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        let textView = try XCTUnwrap(attributedTextView.firstSubview(of: UITextView.self))
        XCTAssertEqual(try XCTUnwrap(textView.attributedText.paragraphAlignment), .right)
    }

    func testShortLabelAlignsWithRightToLeftInterfaceDirection() throws {
        // Given
        let label = AttributedLabel(
            font: .label(.large),
            textColor: .label
        )
        label.semanticContentAttribute = .forceRightToLeft
        label.setText("Test institution")

        // When
        label.layoutIfNeeded()

        // Then
        XCTAssertEqual(try XCTUnwrap(label.attributedText?.paragraphAlignment), .right)
    }

    func testRoundedTextFieldAlignsWithRightToLeftInterfaceDirection() {
        // Given
        let textField = RoundedTextField(
            placeholder: "Account holder name",
            appearance: .stripe
        )
        textField.semanticContentAttribute = .forceRightToLeft

        // When
        textField.layoutIfNeeded()

        // Then
        XCTAssertEqual(textField.textField.textAlignment, .right)
    }

    func testInstitutionSearchAlignsWithRightToLeftInterfaceDirection() throws {
        // Given
        let searchBar = InstitutionSearchBar(appearance: .stripe)
        searchBar.semanticContentAttribute = .forceRightToLeft

        // When
        searchBar.layoutIfNeeded()

        // Then
        let textField = try XCTUnwrap(searchBar.firstSubview(of: UITextField.self))
        XCTAssertEqual(textField.textAlignment, .right)
    }

    func testTestModeBannerAlignsWithRightToLeftInterfaceDirection() throws {
        // Given
        let banner = TestModeAutofillBannerView(
            context: .account,
            appearance: .stripe,
            didTapAutofill: {}
        )
        banner.forceRightToLeftLayout()

        // When
        banner.layoutIfNeeded()

        // Then
        let messageLabel = try XCTUnwrap(
            banner.allSubviews(of: UILabel.self).first {
                $0.attributedText?.string.contains("test mode") == true
            }
        )
        let button = try XCTUnwrap(banner.firstSubview(of: UIButton.self))
        XCTAssertEqual(messageLabel.textAlignment, .right)
        XCTAssertEqual(button.titleLabel?.textAlignment, .left)
    }

    func testPhoneNumberComponentsPreserveLeftToRightOrder() throws {
        // Given
        let phoneTextField = PhoneTextField(
            defaultPhoneNumber: "+14155552671",
            appearance: .stripe
        )

        // When
        phoneTextField.forceRightToLeftLayout()
        phoneTextField.layoutIfNeeded()

        // Then
        let countryCodeSelector = try XCTUnwrap(
            phoneTextField.firstSubview(of: PhoneCountryCodeSelectorView.self)
        )
        let numberStack = try XCTUnwrap(
            phoneTextField.allSubviews(of: UIStackView.self).first {
                $0.arrangedSubviews.contains(countryCodeSelector)
            }
        )
        XCTAssertEqual(numberStack.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(numberStack.effectiveUserInterfaceLayoutDirection, .leftToRight)
    }

    func testRoundedTextFieldExpandsForAccessibilityDynamicType() {
        // Given
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraLarge)
        var roundedTextField: RoundedTextField!
        traits.performAsCurrent {
            roundedTextField = RoundedTextField(
                placeholder: "Account holder name",
                appearance: .stripe
            )
            roundedTextField.text = "Nick Porter"
        }

        // When
        let window = host(
            roundedTextField,
            size: CGSize(width: 390, height: 844),
            traits: traits
        )

        // Then
        XCTAssertNotNil(window.rootViewController)
        XCTAssertGreaterThanOrEqual(
            roundedTextField.textField.bounds.height,
            roundedTextField.textField.font?.lineHeight ?? 0
        )
    }

    func testPhoneCountryCodeDoesNotWrapAtAccessibilityDynamicType() throws {
        // Given
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraLarge)
        var phoneTextField: PhoneTextField!
        traits.performAsCurrent {
            phoneTextField = PhoneTextField(
                defaultPhoneNumber: "+14155552671",
                appearance: .stripe
            )
        }

        // When
        let window = host(
            phoneTextField,
            size: CGSize(width: 390, height: 844),
            traits: traits
        )

        // Then
        XCTAssertNotNil(window.rootViewController)
        let countryCodeLabel = try XCTUnwrap(
            phoneTextField.allSubviews(of: AttributedLabel.self).first {
                $0.attributedText?.string == "+1"
            }
        )
        XCTAssertEqual(countryCodeLabel.numberOfLines, 1)
        XCTAssertEqual(
            countryCodeLabel.contentCompressionResistancePriority(for: .horizontal),
            .required
        )
    }

    func testCloseConfirmationVoiceOverOrderRemainsLogicalInRightToLeftLayout() throws {
        // Given
        let viewController = CloseConfirmationViewController(
            appearance: .stripe,
            didSelectClose: {}
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            UIView.setAnimationsEnabled(animationsWereEnabled)
            window.isHidden = true
        }
        window.rootViewController = viewController
        window.isHidden = false

        // When
        viewController.view.forceRightToLeftLayout()
        window.layoutIfNeeded()

        // Then
        let title = try XCTUnwrap(
            viewController.view.allSubviews(of: UITextView.self).first {
                $0.accessibilityLabel == "Exit without connecting?"
            }
        )
        let cancelButton = try XCTUnwrap(
            viewController.view.allSubviews(of: UIControl.self).first {
                $0.accessibilityLabel == "Cancel"
            }
        )
        let exitButton = try XCTUnwrap(
            viewController.view.allSubviews(of: UIControl.self).first {
                $0.accessibilityLabel == "Yes, exit"
            }
        )
        XCTAssertTrue(cancelButton.isAccessibilityElement)
        XCTAssertTrue(exitButton.isAccessibilityElement)

        let titleFrame = title.convert(title.bounds, to: viewController.view)
        let cancelFrame = cancelButton.convert(cancelButton.bounds, to: viewController.view)
        let exitFrame = exitButton.convert(exitButton.bounds, to: viewController.view)
        XCTAssertLessThan(titleFrame.minY, cancelFrame.minY)
        XCTAssertLessThan(cancelFrame.minY, exitFrame.minY)
    }
}

private extension UIView {
    func firstSubview<View: UIView>(of type: View.Type) -> View? {
        if let view = self as? View {
            return view
        }
        return subviews.lazy.compactMap { $0.firstSubview(of: type) }.first
    }

    func allSubviews<View: UIView>(of type: View.Type) -> [View] {
        let matchingSelf = self as? View
        return [matchingSelf].compactMap { $0 } + subviews.flatMap { $0.allSubviews(of: type) }
    }
}

private extension NSAttributedString {
    var paragraphAlignment: NSTextAlignment? {
        guard length > 0 else {
            return nil
        }
        return (attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment
    }
}

private func host(
    _ view: UIView,
    size: CGSize,
    traits: UITraitCollection
) -> UIWindow {
    let rootViewController = UIViewController()
    let contentViewController = UIViewController()
    rootViewController.addChild(contentViewController)
    rootViewController.setOverrideTraitCollection(traits, forChild: contentViewController)

    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    window.rootViewController = rootViewController
    window.isHidden = false

    contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
    rootViewController.view.addSubview(contentViewController.view)
    NSLayoutConstraint.activate([
        contentViewController.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        contentViewController.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        contentViewController.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
        contentViewController.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
    ])
    contentViewController.didMove(toParent: rootViewController)

    view.translatesAutoresizingMaskIntoConstraints = false
    contentViewController.view.addSubview(view)
    NSLayoutConstraint.activate([
        view.topAnchor.constraint(equalTo: contentViewController.view.topAnchor),
        view.leadingAnchor.constraint(equalTo: contentViewController.view.leadingAnchor, constant: 24),
        view.trailingAnchor.constraint(equalTo: contentViewController.view.trailingAnchor, constant: -24),
    ])
    contentViewController.view.forceRightToLeftLayout()
    window.layoutIfNeeded()
    return window
}
