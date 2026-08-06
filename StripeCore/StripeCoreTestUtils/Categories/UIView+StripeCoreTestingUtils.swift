//
//  UIView+StripeCoreTestingUtils.swift
//  StripeCoreTestUtils
//
//  Created by Mel Ludowise on 10/4/21.
//

import UIKit

extension UIView {
    /// Forces a root view and its current unspecified descendants to use a layout direction in tests.
    ///
    /// Call this after constructing the view hierarchy. Views added later aren't updated, and explicit semantic
    /// content attributes form boundaries that preserve their own subtree's layout direction.
    public func setTestLayoutDirection(_ direction: StripeTestLayoutDirection) {
        semanticContentAttribute = direction.semanticContentAttribute
        subviews
            .filter { $0.semanticContentAttribute == .unspecified }
            .forEach { $0.setTestLayoutDirection(direction) }
        setNeedsLayout()
        layoutIfNeeded()
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
