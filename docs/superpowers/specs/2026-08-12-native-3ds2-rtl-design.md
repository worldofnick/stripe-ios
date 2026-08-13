# Native 3DS2 right-to-left support

## Objective

Add a small, standalone native Stripe3DS2 RTL change based on upstream `master`, fixing only behavior that UIKit does not already provide automatically. The change does not add Arabic translations or modify ACS-hosted HTML.

## Verified master behavior

Current upstream `master` (`1e451705aca`) was built and exercised in `Stripe3DS2DemoUI` on the iOS 18.0 iPhone 12 mini with:

```text
-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES
```

UIKit already provides these behaviors without production changes:

- The Cancel navigation action moves to the physical left in RTL.
- Native labels use natural RTL alignment.
- The whitelist row's system `UIStackView` mirrors its checkbox and label.
- Progress and payment-network branding remain centered and unmirrored.
- Issuer and payment-network logos remain visually unflipped.

The branch must not add code for those behaviors.

## Required production changes

### Custom horizontal stack layout

`STDSStackView` currently uses physical left/right Auto Layout attributes for horizontal arrangement. Replace those horizontal relationships with leading/trailing relationships so the custom layout follows its effective interface direction.

This shared fix must make the following existing native components semantic without component-specific reordering:

- single-select radio rows;
- multi-select checkbox rows;
- the out-of-band status icon and text;
- expandable information indicator and text;
- issuer/payment-system branding order.

Brand images themselves must remain unmirrored, consistent with Apple's RTL guidance.

### Expandable indicator

The collapsed expandable-information chevron communicates horizontal direction and must point toward the RTL reading direction. Prepare the image to flip automatically in RTL while preserving the existing expanded/down rotation.

### Verification-code field

`STDSTextField` overrides `textRectForBounds:` and `editingRectForBounds:` with a symmetrical inset. That discards the rect UIKit reserves for the clear button. Start with the superclass-provided rect, then apply the existing text margin so the intrinsically LTR verification code cannot overlap the RTL clear control.

## Testing

Keep automated coverage focused:

- one layout test proving a horizontal `STDSStackView` reverses semantic order under forced RTL while vertical layout remains unchanged;
- one test proving the expandable chevron is configured for RTL flipping;
- one text-field geometry test proving the editing rect does not intersect the visible clear-button rect in RTL.

Each test must fail on unmodified master before production code is changed. Run only the affected Stripe3DS2 test target or individual tests, plus a build of `Stripe3DS2DemoUI`.

## Simulator verification and evidence

Use the same iOS 18.0 iPhone 12 mini and forced-RTL launch arguments. Capture matched before/after screenshots only for visible behavior changed by this branch:

- single-select row;
- expanded help row;
- out-of-band status row;
- entered verification code with its clear button.

Interact with the selection row, expandable control, and verification-code field to confirm behavior beyond static layout. Do not add screenshots for navigation, whitelist, progress, logos, dark mode, or ACS HTML because this branch does not change them.

## Branch and delivery

- Branch: `codex/rtl-native-3ds2`
- Base: upstream `master` at `1e451705aca`
- Push only to `worldofnick/stripe-ios`.
- Do not open a pull request against `stripe/stripe-ios`.
- Keep production changes limited to native Stripe3DS2 RTL behavior and avoid localization files.

## Out of scope

- Arabic translations and Arabic snapshot references;
- ACS-hosted HTML directionality and localization;
- Financial Connections web content;
- iPad, landscape, Dynamic Type, and full VoiceOver traversal audits;
- broad snapshot expansion or the full Stripe iOS test suite.
