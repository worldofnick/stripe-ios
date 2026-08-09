# PR4 RTL Simulator evidence

These screenshots were captured by manually operating the `PaymentSheet Example`
app in Simulator. They are not XCTest or snapshot-test output.

| | Value |
| --- | --- |
| Before | `920f509cf0f` (`codex/rtl-checkout-components`) |
| After production code | `cc0b75c5a3b` |
| Simulator | iPhone 12 mini, iOS 18.0 (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`) |
| App | `com.stripe.PaymentSheet-Example` |
| Launch | Normal launch with `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`; no `UITesting` environment |
| Capture | Native Simulator framebuffer via `xcrun simctl io … screenshot`; no desktop window, pointer, or overlay |
| Xcode | 26.4.1 (17E202) |
| Before `StripePaymentSheet` SHA-256 | `273096870ba4b24f55716a050f8399809252d571fb20844564e07c02d6d676d3` |
| After `StripePaymentSheet` SHA-256 | `436b3769572f625c4fcfb45778ad27996eaeb6333d255141222233e3090d10f5` |

## Verification header

Oracle: Link verification already includes this close control in LTR. Before, its
physical-right constraint collides with the RTL-leading logo, hiding the existing
control and raising a broken-constraint diagnostic. After, the logo occupies the
RTL leading side and the existing close control occupies the trailing side.

| Before | After |
| --- | --- |
| ![Before: Link verification header is not mirrored](before-verification.jpg) | ![After: Link verification header is mirrored](after-verification.jpg) |

The parent also raises the repository's `Broken constraint!` diagnostic when this
screen is presented. The final branch does not raise it.

![Before: broken close-button width constraint alert](before-verification-constraint-alert.jpg)

## Wallet header

Oracle: the Link wallet uses the same mirrored leading-logo/trailing-close
placement. Before, the logo is left and close is missing. After, both controls are
visible in the correct RTL positions.

| Before | After |
| --- | --- |
| ![Before: Link wallet header is not mirrored](before-wallet.jpg) | ![After: Link wallet header is mirrored](after-wallet.jpg) |

## Add-payment-method navigation

Oracle: a back control on the RTL trailing side points right, toward the previous
screen. Before, it incorrectly points left. After, it points right.

| Before | After |
| --- | --- |
| ![Before: RTL back chevron points left](before-add-payment-method.jpg) | ![After: RTL back chevron points right](after-add-payment-method.jpg) |
