import UIKit

enum PlaygroundLayoutDirection {
    @MainActor
    static func apply(
        _ layoutDirection: PaymentSheetTestPlaygroundSettings.LayoutDirection?,
        to window: UIWindow
    ) {
        switch layoutDirection ?? .system {
        case .system:
            window.semanticContentAttribute = .unspecified
        case .leftToRight:
            window.semanticContentAttribute = .forceLeftToRight
        case .rightToLeft:
            window.semanticContentAttribute = .forceRightToLeft
        }
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }
}
