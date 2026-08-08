# PR3 RTL Simulator evidence

These screenshots were captured by manually operating the `PaymentSheet Example`
app in Simulator. They are not XCTest or snapshot-test output.

| | Value |
| --- | --- |
| Before | `4931a8cfc20271084946baa46714035c89437df9` (`codex/rtl-paymentsheet`) |
| After production code | `0a05a62e258` |
| Simulator | iPhone 12 mini, iOS 18.0 (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`) |
| App | `com.stripe.PaymentSheet-Example` |
| Launch | Normal launch with `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`; no `UITesting` environment |
| Xcode | 26.4.1 (17E202) |
| Before executable SHA-256 | `adde0c26a0e3a36ae5389b6f0b4b2adf508f56183178ea11fb19b50daf8b322e` |
| After executable SHA-256 | `fd8d1ff3142b280c924199ccfbd7ab3abcb957cb0f69861c665646b70549bdb9` |

The native Financial Connections screens end before any bank-owned web view.
Bank authentication web content was deliberately excluded from this audit.

## Institution search

Oracle: an active short-text search value follows the RTL interface alignment.
Before, `Success` snaps to the left when entered. After, it remains right-aligned.

| Before | After |
| --- | --- |
| ![Before: active institution search value is left-aligned](before-institution-search.jpg) | ![After: active institution search value is right-aligned](after-institution-search.jpg) |

## Phone field

Oracle: phone data preserves its intrinsic LTR order while the surrounding UI is
RTL. Before, the country code appears on the trailing side. After, `+1` and the
formatted number form one contiguous LTR compound field on the leading side.

| Before | After |
| --- | --- |
| ![Before: phone country code is on the RTL trailing side](before-phone-field.jpg) | ![After: phone country code and number remain contiguous LTR](after-phone-field.jpg) |

## Exit confirmation direction icon

Oracle: the directional icon mirrors with the interface. Before, it points right.
After, it points left. Both captures use the same verification-screen state.

| Before | After |
| --- | --- |
| ![Before: exit confirmation icon points right](before-close-confirmation.jpg) | ![After: exit confirmation icon points left](after-close-confirmation.jpg) |
