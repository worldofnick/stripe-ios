# PR7 RTL Simulator evidence

These screenshots were captured by manually operating the flat-with-disclosure
`EmbeddedPaymentElement` row style in the production PaymentSheet playground.
They are not XCTest or snapshot-test output.

| | Value |
| --- | --- |
| Before | `51e1da491f1` (`codex/rtl-flow-controller`) |
| After production and test changes | `85f2544ff68` |
| Simulator | iPhone 12 mini, iOS 18.0 (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`) |
| App | `com.stripe.PaymentSheet-Example` |
| Launch | Normal launch with `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`; no `UITesting` environment |
| Capture | Native Simulator framebuffer via `xcrun simctl io ... screenshot`; no desktop cursor or Simulator chrome |
| Xcode | 26.4.1 (17E202) |
| Before `StripePaymentSheet` SHA-256 | `436b3769572f625c4fcfb45778ad27996eaeb6333d255141222233e3090d10f5` |
| After `StripePaymentSheet` SHA-256 | `287f5aa8ce5579e26daa8102282078f5857c98af64ab2ccb3b3d909accf2859e` |

This pair demonstrates PR7's production change. The default Stripe chevron now
points toward RTL forward navigation; merchant-supplied custom disclosure
artwork is deliberately not modified.

## Flat with disclosure

This style was exercised with the required `immediateAction` row-selection
behavior. Oracle: disclosure indicators stay on the RTL leading edge and point
left, the forward-navigation direction in RTL.

| Before | After |
| --- | --- |
| ![Before: disclosure chevrons incorrectly point right](before-flat-disclosure.jpg) | ![After: disclosure chevrons correctly point left](after-flat-disclosure.jpg) |
