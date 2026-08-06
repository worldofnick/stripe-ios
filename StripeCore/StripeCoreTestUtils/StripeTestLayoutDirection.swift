import SwiftUI
import UIKit

public enum StripeTestLayoutDirection {
    case leftToRight
    case rightToLeft

    var semanticContentAttribute: UISemanticContentAttribute {
        switch self {
        case .leftToRight:
            return .forceLeftToRight
        case .rightToLeft:
            return .forceRightToLeft
        }
    }

    var swiftUILayoutDirection: LayoutDirection {
        switch self {
        case .leftToRight:
            return .leftToRight
        case .rightToLeft:
            return .rightToLeft
        }
    }
}
