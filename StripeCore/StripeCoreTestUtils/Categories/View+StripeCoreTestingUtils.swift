import SwiftUI

extension View {
    /// Forces a SwiftUI root and its descendants to use a layout direction in tests.
    public func testLayoutDirection(_ direction: StripeTestLayoutDirection) -> some View {
        environment(\.layoutDirection, direction.swiftUILayoutDirection)
    }
}
