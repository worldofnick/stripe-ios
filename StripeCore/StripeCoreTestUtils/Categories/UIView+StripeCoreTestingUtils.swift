//
//  UIView+StripeCoreTestingUtils.swift
//  StripeCoreTestUtils
//
//  Created by Mel Ludowise on 10/4/21.
//

import UIKit

extension UIView {
    /// Forces this view hierarchy into a right-to-left layout without changing the app's language or global appearance state.
    /// Descendants inherit this direction unless they explicitly preserve left-to-right semantics for directional data.
    public func forceRightToLeftLayout() {
        semanticContentAttribute = .forceRightToLeft
        setNeedsLayout()
        subviews.forEach { $0.forceRightToLeftLayoutIfUnspecified() }
    }

    private func forceRightToLeftLayoutIfUnspecified() {
        // Preserve explicit semantics such as OneTimeCodeTextField's left-to-right digit order.
        guard semanticContentAttribute == .unspecified else { return }
        semanticContentAttribute = .forceRightToLeft
        setNeedsLayout()
        subviews.forEach { $0.forceRightToLeftLayoutIfUnspecified() }
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
