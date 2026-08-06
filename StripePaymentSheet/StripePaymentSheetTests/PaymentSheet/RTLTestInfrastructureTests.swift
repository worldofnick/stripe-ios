import StripeCoreTestUtils
import SwiftUI
import UIKit
import XCTest

@MainActor
final class RTLTestInfrastructureTests: XCTestCase {
    func testUIKitRootOverridePropagatesToNestedUnspecifiedDescendants() {
        let rightToLeftRootView = UIView()
        let rightToLeftChildView = UIView()
        let rightToLeftGrandchildView = UIView()
        rightToLeftRootView.addSubview(rightToLeftChildView)
        rightToLeftChildView.addSubview(rightToLeftGrandchildView)

        rightToLeftRootView.setTestLayoutDirection(.rightToLeft)

        XCTAssertEqual(rightToLeftRootView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(rightToLeftChildView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(rightToLeftGrandchildView.effectiveUserInterfaceLayoutDirection, .rightToLeft)

        let leftToRightRootView = UIView()
        let leftToRightChildView = UIView()
        let leftToRightGrandchildView = UIView()
        leftToRightRootView.addSubview(leftToRightChildView)
        leftToRightChildView.addSubview(leftToRightGrandchildView)

        leftToRightRootView.setTestLayoutDirection(.leftToRight)

        XCTAssertEqual(leftToRightRootView.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(leftToRightChildView.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(leftToRightGrandchildView.effectiveUserInterfaceLayoutDirection, .leftToRight)
    }

    func testUIKitRootOverridePreservesExplicitSemanticSubtree() {
        let rootView = UIView()
        let unspecifiedChildView = UIView()
        let explicitLeftToRightView = UIView()
        let descendantOfExplicitView = UIView()
        rootView.addSubview(unspecifiedChildView)
        rootView.addSubview(explicitLeftToRightView)
        explicitLeftToRightView.addSubview(descendantOfExplicitView)
        explicitLeftToRightView.semanticContentAttribute = .forceLeftToRight

        rootView.setTestLayoutDirection(.rightToLeft)

        XCTAssertEqual(rootView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(unspecifiedChildView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(explicitLeftToRightView.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(explicitLeftToRightView.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(descendantOfExplicitView.semanticContentAttribute, .unspecified)
    }

    func testUIKitRootOverrideReversesHelperOwnedDescendantsWithoutCrossingExplicitBoundary() {
        let rootView = UIView()
        let helperOwnedChildView = UIView()
        let helperOwnedGrandchildView = UIView()
        let explicitRightToLeftView = UIView()
        let descendantOfExplicitView = UIView()
        rootView.addSubview(helperOwnedChildView)
        helperOwnedChildView.addSubview(helperOwnedGrandchildView)
        rootView.addSubview(explicitRightToLeftView)
        explicitRightToLeftView.addSubview(descendantOfExplicitView)
        explicitRightToLeftView.semanticContentAttribute = .forceRightToLeft

        rootView.setTestLayoutDirection(.rightToLeft)
        rootView.setTestLayoutDirection(.leftToRight)

        XCTAssertEqual(rootView.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(helperOwnedChildView.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(helperOwnedGrandchildView.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(explicitRightToLeftView.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(explicitRightToLeftView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(descendantOfExplicitView.semanticContentAttribute, .unspecified)
    }

    func testUIKitRootOverrideOnlyAppliesToCurrentSubviewTree() {
        let rootView = UIView()

        rootView.setTestLayoutDirection(.rightToLeft)

        let laterAddedView = UIView()
        rootView.addSubview(laterAddedView)

        XCTAssertEqual(laterAddedView.semanticContentAttribute, .unspecified)
    }

    func testSwiftUIRootOverridePropagatesThroughEnvironment() async {
        let didObserveRTL = expectation(description: "SwiftUI observes the forced RTL environment")
        didObserveRTL.assertForOverFulfill = false
        var observedDirection: LayoutDirection?
        let reader = LayoutDirectionReader { direction in
            observedDirection = direction
            if direction == .rightToLeft {
                didObserveRTL.fulfill()
            }
        }
        let hostingController = UIHostingController(
            rootView: reader.testLayoutDirection(.rightToLeft)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = hostingController
        window.isHidden = false

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        await fulfillment(of: [didObserveRTL], timeout: 1)

        XCTAssertEqual(observedDirection, .rightToLeft)
    }

    func testSwiftUIRootOverrideMapsLeftToRightThroughEnvironment() async {
        let didObserveLTR = expectation(description: "SwiftUI observes the forced LTR environment")
        didObserveLTR.assertForOverFulfill = false
        var observedDirection: LayoutDirection?
        let reader = LayoutDirectionReader { direction in
            observedDirection = direction
            if direction == .leftToRight {
                didObserveLTR.fulfill()
            }
        }
        let hostingController = UIHostingController(
            rootView: reader
                .testLayoutDirection(.leftToRight)
                .testLayoutDirection(.rightToLeft)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = hostingController
        window.isHidden = false

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        await fulfillment(of: [didObserveLTR], timeout: 1)

        XCTAssertEqual(observedDirection, .leftToRight)
    }
}

private struct LayoutDirectionReader: UIViewRepresentable {
    @Environment(\.layoutDirection) private var layoutDirection
    let didUpdate: (LayoutDirection) -> Void

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        didUpdate(layoutDirection)
    }
}
