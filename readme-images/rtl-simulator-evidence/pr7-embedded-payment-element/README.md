# PR7 RTL Simulator evidence

These screenshots were captured by manually operating the flat-with-disclosure
`EmbeddedPaymentElement` row style in the production PaymentSheet playground.
They are not XCTest or snapshot-test output.

| | Value |
| --- | --- |
| Before | `0c9d734e3a0` (`codex/rtl-link`) |
| After production and test changes | `af7dacd1b82` |
| Simulator | iPhone 12 mini, iOS 18.0 (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`) |
| App | `com.stripe.PaymentSheet-Example` |
| Launch | Normal launch with `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`; no `UITesting` environment |
| Capture | Native Simulator framebuffer via `xcrun simctl io ... screenshot`; no desktop cursor or Simulator chrome |
| Xcode | 26.4.1 (17E202) |
| Before `StripePaymentSheet` SHA-256 | `477b4349bcb7d2c7dc0e98d9ecfb2754c8cfe0501ee74709f634726e3d16a2c2` |
| After `StripePaymentSheet` SHA-256 | `dd03b98607c9935fbab60c311bd98133d85315149713c23a315870ceff17e8f5` |

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
