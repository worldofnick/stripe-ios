# PaymentSheet and Related UI RTL Support

**Status:** Approved

**Date:** 2026-08-06

**Implementation basis:** Fresh work from `upstream/master`. Existing experimental RTL branches are not implementation inputs and must not be cherry-picked.

## Summary

Add conventional right-to-left (RTL) behavior to PaymentSheet and the native payment experiences it owns or launches. Production UI inherits layout direction from the host application without a new merchant-facing API. Stripe tests and the PaymentSheet test playground can force RTL at a presentation root for automated and manual QA.

Delivery is foundation-first and split across multiple narrowly scoped pull requests. Shared controls are corrected before product surfaces, and every phase preserves existing left-to-right (LTR) behavior.

## Goals

- Make all in-scope native UI behave correctly when the host application uses an RTL layout direction.
- Follow Apple's RTL conventions for mirroring, bidirectional text, numbers, structured identifiers, imagery, navigation, interaction, and accessibility.
- Fix shared primitives once so PaymentSheet-related products inherit consistent behavior.
- Provide an internal automated-test override and an easy PaymentSheet test-playground RTL toggle.
- Add risk-based comprehensive coverage across shared primitives and every major surface.
- Deliver the work as a dependency-ordered series of reviewable pull requests.

## Non-goals

- Shipping Arabic, Hebrew, Persian, Urdu, or other translations. The localization team owns translated strings.
- Adding a public PaymentSheet layout-direction configuration.
- Supporting live direction changes in an already-presented flow.
- Modifying system-owned, issuer-owned, or remotely rendered UI.
- Modernizing every UI module in the Stripe iOS repository.
- Treating previous experimental RTL branches as a source of implementation changes.

## Scope

### In scope

- Shared controls used by the payment experiences in `StripeUICore` and `StripePaymentsUI`.
- PaymentSheet, including modal and vertical presentations and all new, saved, edit, removal, loading, error, mandate, and confirmation states.
- `PaymentSheet.FlowController`.
- `EmbeddedPaymentElement` (EPE), including UIKit and SwiftUI entry points.
- `CustomerSheet`.
- `AddressElement`, including address autocomplete and country selection.
- Checkout Payment Element, Express Checkout Element, and Currency Selector Element.
- Native Link UI launched or embedded by PaymentSheet.
- FC Lite and Payment Method Messaging native chrome.
- Native Financial Connections UI launched by an in-scope payment flow.
- Stripe-owned 3DS2 presentation and challenge chrome launched by an in-scope payment flow.
- Native transitions into externally rendered content and propagation of locale information across those boundaries.

### Out of scope

- Apple Pay and other system-owned sheets.
- Bank authentication, hosted Link or Financial Connections pages, and issuer-controlled 3DS challenge content.
- Native UI unrelated to PaymentSheet or the payment flows listed above.

External content remains separately owned. This initiative verifies that Stripe's native chrome is correct and that existing locale information reaches the external boundary; external RTL rendering is not an iOS SDK acceptance criterion.

## RTL Behavioral Contract

The implementation follows Apple's [Right-to-left Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/right-to-left) and [UIKit RTL guidance](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/SupportingRight-To-LeftLanguages/SupportingRight-To-LeftLanguages.html).

### Layout and direction

- Production UI inherits the host application's effective layout direction.
- UIKit code uses effective semantic layout direction; SwiftUI code inherits the environment's `layoutDirection`.
- Code must not infer layout direction from a hard-coded list of language identifiers.
- Structural layouts use leading/trailing semantics and mirror automatically.
- Custom layout calculations, ordering, transitions, and animations consult effective layout direction.
- Direction is resolved when a flow is created or presented. Dismissing and reopening is required after changing the test-playground direction.
- No application-global `UIAppearance` or equivalent mutation is permitted.

### Text and structured values

- Ordinary text uses natural alignment and natural writing direction.
- Mixed Arabic, Hebrew, Latin, numeric, and merchant-provided content relies on standard bidirectional text behavior by default.
- Localized strings containing interpolated values use localized formatting and add Unicode isolation only when standard behavior is demonstrably incorrect.
- Digits in a specific number retain their logical sequence.
- Card numbers, expiry dates, CVCs, phone numbers, emails, IBANs, postal codes, amounts, and verification codes preserve conventional entry and display order without forcing an entire surrounding row to LTR.
- Forced LTR or RTL semantics are applied only to the smallest content boundary that requires them.

### Controls, imagery, and interaction

- Navigation order, horizontal control order, disclosure indicators, progress direction, paging, and direction-bearing arrows mirror.
- Directional artwork uses automatically mirrored images or direction-aware assets.
- Logos, card-brand artwork, QR codes, clocks, and nondirectional imagery do not mirror.
- Accessibility traversal and focus order match the visual reading order.
- Existing LTR appearance, interaction, input behavior, and accessibility remain unchanged.

## Architecture

RTL support is divided into four layers.

1. **Testing controls** force direction at a test or playground presentation root without changing the production API.
2. **Shared UI primitives** implement common form, row, navigation, selector, image, and text behavior once.
3. **Product surfaces** inherit shared behavior and contain only product-specific exceptions or custom-layout fixes.
4. **External boundaries** preserve correct native chrome and locale handoff while leaving external rendering to its owner.

Layout direction is presentation context, not checkout state. It must not be added to PaymentSheet models, confirmation state, session updates, analytics, or network requests beyond verifying the locale fields already sent at external boundaries.

There is no RTL-specific runtime error. A failure to mirror native content is a UI defect caught through tests and QA; it must not prevent checkout or introduce a production fallback. Lack of RTL support in external content likewise does not become a PaymentSheet error.

## Pull Request Sequence

### PR 1: RTL test infrastructure and playground control

- Add shared UIKit and SwiftUI test helpers that force direction at a root boundary.
- Add a PaymentSheet test-playground RTL toggle.
- Ensure the toggle affects subsequently presented flows and does not promise live mutation.
- Establish representative proof that the override reaches UIKit, SwiftUI, and mixed presentation boundaries.

### PR 2: StripeUICore foundations

- Audit and correct text fields, floating placeholders, pickers, dropdowns, address and phone fields, checkboxes, mandates, separators, reusable rows, and related shared elements.
- Add mixed-direction and structured-value coverage at the primitive level.

### PR 3: StripePaymentsUI foundations

- Audit and correct legacy card fields and forms, card-brand decorations, validation accessories, and remaining primitives consumed by PaymentSheet.
- Verify card artwork and structured values remain semantically correct.

### PR 4: PaymentSheet core

- Cover modal and vertical layouts, new and saved payment-method screens, editing and removal, navigation, errors, mandates, loading, selectors, and card scanning.

### PR 5: FlowController

- Cover presentation boundaries, saved and new method flows, direct-to-form behavior, navigation, dismissal, and state restoration.

### PR 6: CustomerSheet

- Cover saved-method lists, add, edit and remove flows, empty, error and loading states, and navigation.

### PR 7: AddressElement

- Cover the address form, country selection, autocomplete, search results, errors, and UIKit and SwiftUI presentation.

### PR 8: EmbeddedPaymentElement

- Cover collapsed and expanded states, saved-method styles, embedded forms, disclosure indicators, errors, mandates, and SwiftUI wrappers.

### PR 9: Checkout Elements

- Cover Payment Element, Express Checkout Element, Currency Selector Element, session-update states, and native wallet-button containers.

### PR 10: Native Link

- Cover inline signup and verification, wallet, payment-method picker, consent and KYC, errors, toasts, and navigation.

### PR 11: Related native flows

- Cover FC Lite, Payment Method Messaging native chrome, native Financial Connections UI, and Stripe-owned 3DS2 presentation and challenge chrome.

### PR 12: Cross-flow verification and handoffs

- Verify external-content locale handoffs.
- Audit accessibility order.
- Perform the final LTR regression sweep.
- Audit remaining physical left/right assumptions and document intentional spatial or invariant exceptions.
- Close gaps found across surface boundaries.

Each surface PR depends on the foundation PRs but remains narrowly owned. A surface that inherits correct behavior may add representative tests without unnecessary production changes.

## Verification Strategy

### Shared-component tests

- Assert effective direction, semantic ordering, natural alignment, and icon behavior.
- Exercise Arabic, Hebrew, Latin, numeric, and mixed bidirectional test strings without shipping translations.
- Verify logical order for card numbers, expiry, CVC, phone, email, IBAN, postal code, amount, and verification code values.
- Cover multiline labels, validation errors, placeholders, accessories, and Dynamic Type.

### Surface snapshots and interaction tests

- Add representative RTL snapshots for every major surface and presentation style.
- Select primary, loading, error, empty, saved-method, new-method, editing, mandate, and confirmation states according to each surface's risk.
- Use a baseline phone portrait configuration plus targeted iPad, landscape, and large Dynamic Type cases.
- Verify navigation, disclosure controls, collection ordering, paging and swiping, focus movement, animation direction, and accessibility traversal.
- Avoid multiplying every payment method by every device configuration when those cases share the same primitives.

### Regression requirements

- Existing LTR snapshots and behavior remain unchanged unless an independently justified defect is found.
- Each PR runs focused tests for its module and affected dependents.
- Local Stripe iOS simulator testing uses the configured iOS 18.0 iPhone 12 mini.
- The final phase performs a cross-surface smoke pass and an audit of remaining physical-direction assumptions.

### Manual QA

- The PaymentSheet test playground can force RTL without requiring translated bundles.
- QA uses Arabic and mixed-direction keyboard input across representative forms.
- Actual localized RTL builds receive a final smoke pass when localization bundles become available.
- External flows are checked for native chrome, locale handoff, and clean transitions only.

## Pull Request Acceptance Criteria

Every PR must include:

- A narrowly defined component or surface boundary.
- Production changes limited to defects demonstrated by the audit or tests.
- Focused automated RTL coverage.
- Before/after visual evidence when layout changes.
- Confirmation that relevant LTR tests remain unchanged.
- A short audit note identifying reviewed states and intentional exceptions.

The series ships incrementally without a feature flag. Each PR must be independently safe for LTR users; RTL behavior activates through the host environment after the relevant foundations and surface fixes land.

## Program Completion Criteria

The initiative is complete when:

- Every in-scope native surface inherits RTL automatically.
- Shared controls handle mixed-direction text and structured values according to the behavioral contract.
- Navigation, interaction direction, animation, icons, and accessibility order match the mirrored layout.
- No public direction API or global appearance override is required.
- External transitions preserve correct native chrome and locale handoff.
- The risk-based device and state matrix passes.
- Remaining physical left/right code in scope is either replaced or documented as intentionally spatial or invariant.

## Planning Strategy

This document is the program-level contract. The first implementation plan covers PR 1 only: RTL test infrastructure and the PaymentSheet test-playground control. Each later PR receives its own focused plan under this contract before implementation begins.
