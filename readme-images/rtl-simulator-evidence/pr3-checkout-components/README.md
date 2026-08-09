# PR3 RTL Simulator evidence

These screenshots were captured by manually operating the `PaymentSheet Example`
app in Simulator. They are not XCTest or snapshot-test output.

| | Value |
| --- | --- |
| Before | `96da13bed7e` (`codex/rtl-paymentsheet`) |
| After production code | `0e111d858ce` |
| Simulator | iPhone 12 mini, iOS 18.0 (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`) |
| App | `com.stripe.PaymentSheet-Example` |
| Launch | Normal launch with `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`; no `UITesting` environment |
| Capture | Native Simulator framebuffer via `xcrun simctl io … screenshot`; no desktop window, pointer, or overlay |
| Xcode | 26.4.1 (17E202) |
| Before `StripeFinancialConnections` SHA-256 | `312a8b64dbd8c0ade27e3001d0b9e9049075402c55e464bb826f285658a1fa66` |
| After `StripeFinancialConnections` SHA-256 | `5bb68b1bd23771bc75ed9a336e8176cf8cad67a05b2a312610d56e9dc4aad332` |

The native Financial Connections screens end before any bank-owned web view.
Bank authentication web content was deliberately excluded from this audit.
Institution-search and account-holder-name screenshots are also excluded: they
had identical before and after pixels, so their explicit RTL overrides were
removed from the production diff.

## Phone field

Oracle: phone data preserves its intrinsic LTR order while the surrounding UI is
RTL. Before, the country code appears on the trailing side. After, `+1` and the
formatted number form one contiguous LTR compound field on the leading side.

| Before | After |
| --- | --- |
| ![Before: phone country code is on the RTL trailing side](before-phone-field.jpg) | ![After: phone country code and number remain contiguous LTR](after-phone-field.jpg) |

## Exit confirmation direction icon

Oracle: the directional icon mirrors with the interface. Before, it points right.
After, it points left. Both captures use the same institution-search state.

| Before | After |
| --- | --- |
| ![Before: exit confirmation icon points right](before-close-confirmation.jpg) | ![After: exit confirmation icon points left](after-close-confirmation.jpg) |
