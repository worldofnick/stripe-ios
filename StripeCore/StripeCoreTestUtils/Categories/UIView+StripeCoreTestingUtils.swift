//
//  UIView+StripeCoreTestingUtils.swift
//  StripeCoreTestUtils
//
//  Created by Mel Ludowise on 10/4/21.
//

import ObjectiveC
import UIKit

private var testLayoutDirectionOwnershipKey: UInt8 = 0

extension UIView {
    /// Forces a root view and its current unspecified descendants to use a layout direction in tests.
    ///
    /// Call this after constructing the view hierarchy. Views added later aren't updated, and explicit semantic
    /// content attributes form boundaries that preserve their own subtree's layout direction.
    public func setTestLayoutDirection(_ direction: StripeTestLayoutDirection) {
        setTestLayoutDirection(direction, helperOwnsOverride: false)
    }

    private func setTestLayoutDirection(
        _ direction: StripeTestLayoutDirection,
        helperOwnsOverride: Bool
    ) {
        semanticContentAttribute = direction.semanticContentAttribute
        helperOwnedSemanticContentAttribute = helperOwnsOverride ? direction.semanticContentAttribute : nil
        subviews
            .filter { $0.semanticContentAttribute == .unspecified || $0.hasHelperOwnedSemanticContentAttribute }
            .forEach { $0.setTestLayoutDirection(direction, helperOwnsOverride: true) }
        setNeedsLayout()
        layoutIfNeeded()
    }

    private var helperOwnedSemanticContentAttribute: UISemanticContentAttribute? {
        get {
            guard let rawValue = objc_getAssociatedObject(self, &testLayoutDirectionOwnershipKey) as? NSNumber else {
                return nil
            }
            return UISemanticContentAttribute(rawValue: rawValue.intValue)
        }
        set {
            objc_setAssociatedObject(
                self,
                &testLayoutDirectionOwnershipKey,
                newValue.map { NSNumber(value: $0.rawValue) },
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var hasHelperOwnedSemanticContentAttribute: Bool {
        helperOwnedSemanticContentAttribute == semanticContentAttribute
    }

    /// Constrains the view to the given width and autosizes its height.
    ///
    /// - Parameter width: Resizes the view to this width
    public func autosizeHeight(width: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        setNeedsLayout()
        layoutIfNeeded()
        frame = .init(
            origin: .zero,
            size: systemLayoutSizeFitting(CGSize(width: width, height: UIView.noIntrinsicMetric))
        )
    }
}
