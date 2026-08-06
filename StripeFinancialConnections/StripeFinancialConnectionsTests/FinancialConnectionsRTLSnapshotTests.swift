//
//  FinancialConnectionsRTLSnapshotTests.swift
//  StripeFinancialConnectionsTests
//

@_spi(STP) import StripeCoreTestUtils
@testable @_spi(STP) import StripeFinancialConnections
@_spi(STP) import StripeUICore
import XCTest

final class FinancialConnectionsRTLSnapshotTests: STPSnapshotTestCase {
    private var testWindow: UIWindow?

    override func tearDown() {
        testWindow?.isHidden = true
        testWindow = nil
        super.tearDown()
    }

    func testNativeSurfaceRightToLeft() {
        verifyNativeSurface(
            size: CGSize(width: 390, height: 844),
            traits: UITraitCollection(traitsFrom: [
                UITraitCollection(horizontalSizeClass: .compact),
                UITraitCollection(verticalSizeClass: .regular),
            ])
        )
    }

    func testNativeSurfaceRightToLeftLandscape() {
        verifyNativeSurface(
            size: CGSize(width: 844, height: 390),
            traits: UITraitCollection(traitsFrom: [
                UITraitCollection(horizontalSizeClass: .compact),
                UITraitCollection(verticalSizeClass: .compact),
            ])
        )
    }

    func testNativeSurfaceRightToLeftIPad() {
        verifyNativeSurface(
            size: CGSize(width: 600, height: 800),
            traits: UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceIdiom: .pad),
                UITraitCollection(horizontalSizeClass: .regular),
                UITraitCollection(verticalSizeClass: .regular),
            ])
        )
    }

    func testNativeSurfaceRightToLeftDynamicType() {
        verifyNativeSurface(
            size: CGSize(width: 390, height: 844),
            traits: UITraitCollection(traitsFrom: [
                UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraLarge),
                UITraitCollection(horizontalSizeClass: .compact),
                UITraitCollection(verticalSizeClass: .regular),
            ])
        )
    }

    private func verifyNativeSurface(
        size: CGSize,
        traits: UITraitCollection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let view = makeHostedView(size: size, traits: traits)
        XCTAssertEqual(view.effectiveUserInterfaceLayoutDirection, .rightToLeft, file: file, line: line)
        STPSnapshotVerifyView(
            view,
            suffixes: NSOrderedSet(object: "@3x"),
            file: file,
            line: line
        )
    }

    private func makeHostedView(size: CGSize, traits: UITraitCollection) -> UIView {
        let rootViewController = UIViewController()
        let contentViewController = UIViewController()
        rootViewController.addChild(contentViewController)
        rootViewController.setOverrideTraitCollection(traits, forChild: contentViewController)

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        testWindow = window
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

        var nativeSurface: UIView!
        traits.performAsCurrent {
            nativeSurface = makeNativeSurface()
        }
        contentViewController.view.addAndPinSubview(nativeSurface)
        contentViewController.view.forceRightToLeftLayout()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        return contentViewController.view
    }

    private func makeNativeSurface() -> UIView {
        let searchBar = InstitutionSearchBar(appearance: .stripe)
        searchBar.text = "Test bank"

        let institution = InstitutionCellView(appearance: .stripe)
        institution.customize(
            iconView: RoundedIconView(
                image: .image(.bank),
                style: .rounded,
                appearance: .stripe
            ),
            title: "Test institution",
            subtitle: "Checking and savings"
        )

        let nameField = RoundedTextField(
            placeholder: "Account holder name",
            appearance: .stripe
        )
        nameField.text = "Nick Porter"

        let phoneField = PhoneTextField(
            defaultPhoneNumber: "+14155552671",
            appearance: .stripe
        )

        let testModeBanner = TestModeAutofillBannerView(
            context: .account,
            appearance: .stripe,
            didTapAutofill: {}
        )

        let bodyStack = UIStackView(arrangedSubviews: [
            searchBar,
            institution,
            nameField,
            phoneField,
            testModeBanner,
        ])
        bodyStack.axis = .vertical
        bodyStack.spacing = 12

        let contentView = PaneLayoutView.createContentView(
            iconView: nil,
            title: "Select institution",
            subtitle: "Choose a bank account to continue. Account numbers remain in their original order.",
            contentView: bodyStack
        )
        let footerView = PaneLayoutView.createFooterView(
            primaryButtonConfiguration: .init(
                title: "Continue",
                accessibilityIdentifier: "rtl_test_continue",
                action: {}
            ),
            secondaryButtonConfiguration: .init(
                title: "Cancel",
                accessibilityIdentifier: "rtl_test_cancel",
                action: {}
            ),
            appearance: .stripe
        ).footerView

        let surface = PaneLayoutView(
            contentView: contentView,
            footerView: footerView
        ).createView()
        surface.backgroundColor = FinancialConnectionsAppearance.Colors.background
        return surface
    }
}
