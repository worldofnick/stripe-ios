# iOS right-to-left visual reference

This document is the visual behavior reference for bringing Android's native payment UI into parity with iOS in a right-to-left (RTL) environment. It compares the latest `master` baseline in its normal left-to-right (LTR) layout with the final iOS RTL implementation forced into RTL.

Only comparisons with a visible directional difference are included. The screenshots are real PaymentSheet Playground screens captured directly from the Simulator framebuffer; they do not contain Simulator chrome, a desktop pointer, Xcode, or test-only UI.

## Audit configuration

| | Value |
| --- | --- |
| LTR reference | `9908f613996` (`master`) |
| RTL reference | `0916a917dbaa` (`codex/rtl-natural-text-alignment`, the final production commit in the RTL series) |
| Simulator | iPhone 12 mini, iOS 18.0 |
| App | PaymentSheet Example (`com.stripe.PaymentSheet-Example`) |
| LTR launch | Normal application launch |
| RTL launch | `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES` |
| Capture method | Native framebuffer capture with `xcrun simctl io … screenshot` |
| Design reference | [Apple Human Interface Guidelines: Right to left](https://developer.apple.com/design/human-interface-guidelines/right-to-left) |

The RTL reference deliberately uses English strings. It validates layout direction, semantic placement, directional imagery, and mixed-direction data without claiming Arabic localization quality. Arabic snapshot coverage is deferred until translations are available.

## Cross-platform behavior to match

- Treat leading and trailing as semantic edges. In RTL, leading is physically right and trailing is physically left.
- Reverse logical horizontal order where order communicates progression, such as payment-method carousels and segmented choices.
- Mirror directional navigation artwork. Back points right; forward/disclosure indicators point left.
- Keep close, back, edit, overflow, selection, and accessory controls on their semantic edge.
- Use natural text alignment for headings, labels, legal text, and mandates. Do not hard-code physical left or right alignment.
- Preserve the internal LTR ordering of intrinsically LTR data such as prices, card numbers, expiration dates, emails, phone numbers, and Latin-script addresses, even when their containers move to the RTL leading edge.
- Do not mirror brand logos, flags, payment-method artwork, card art, QR codes, or other non-directional imagery.
- Do not automatically flip merchant-provided custom artwork. Only known directional system/Stripe indicators should be mirrored.
- Keep a text link attached to the logical end of its sentence. With English text forced into an RTL UI, that can still be the physical right edge because the text run itself remains LTR.

## Coverage

| Surface | Retained comparisons |
| --- | ---: |
| PaymentSheet — vertical layout | 8 |
| PaymentSheet — horizontal layout | 3 |
| CustomerSheet | 6 |
| PaymentSheet.FlowController | 3 |
| EmbeddedPaymentElement | 6 |
| Link | 6 |
| Checkout components | 5 |
| Payment-method-specific states | 2 |
| **Total** | **39** |

## PaymentSheet — vertical layout

### Main payment-method screen

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet vertical main screen in LTR](ltr/payment-sheet-vertical/main.png) | ![PaymentSheet vertical main screen in RTL](rtl/payment-sheet-vertical/main.png) |

**Android behavior:** Mirror row content and accessories around semantic leading/trailing edges while keeping payment brands and account data unmirrored.

### Saved payment methods

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet saved methods in LTR](ltr/payment-sheet-vertical/saved-methods.png) | ![PaymentSheet saved methods in RTL](rtl/payment-sheet-vertical/saved-methods.png) |

**Android behavior:** Place payment artwork at RTL leading and the forward accessory at RTL trailing; the accessory points left toward forward navigation.

### Edit saved payment methods

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet edit saved methods in LTR](ltr/payment-sheet-vertical/edit-saved-methods.png) | ![PaymentSheet edit saved methods in RTL](rtl/payment-sheet-vertical/edit-saved-methods.png) |

**Android behavior:** Mirror the navigation action, row ordering, and edit/remove affordances semantically; card artwork and last-four digits retain their own orientation.

### Manage bank account

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet bank account management in LTR](ltr/payment-sheet-vertical/manage-bank.png) | ![PaymentSheet bank account management in RTL](rtl/payment-sheet-vertical/manage-bank.png) |

**Android behavior:** Mirror the sheet controls and label/value layout, but keep the account suffix readable in its intrinsic numeric direction.

### Remove bank account confirmation

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet remove bank confirmation in LTR](ltr/payment-sheet-vertical/remove-bank-confirmation.png) | ![PaymentSheet remove bank confirmation in RTL](rtl/payment-sheet-vertical/remove-bank-confirmation.png) |

**Android behavior:** Use RTL reading order and semantic action placement in the confirmation state; do not reverse digits inside the account identifier.

### Manage card

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet card management in LTR](ltr/payment-sheet-vertical/manage-card.png) | ![PaymentSheet card management in RTL](rtl/payment-sheet-vertical/manage-card.png) |

**Android behavior:** Mirror navigation, labels, menus, and switches while leaving card brand, last four, and expiration data internally LTR.

### Card form and inline Link signup

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet card form in LTR](ltr/payment-sheet-vertical/card-form.png) | ![PaymentSheet card form in RTL](rtl/payment-sheet-vertical/card-form.png) |

**Android behavior:** Align labels and placeholders naturally and mirror field accessories. Numeric card-entry fields retain LTR input order inside the RTL form, while the inline Link signup/legal copy uses natural paragraph alignment.

### Card scanner

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet card scanner in LTR](ltr/payment-sheet-vertical/card-scanner.png) | ![PaymentSheet card scanner in RTL](rtl/payment-sheet-vertical/card-scanner.png) |

**Android behavior:** Move the close control from physical right to RTL trailing on the left. The camera frame itself is non-directional and does not mirror.

## PaymentSheet — horizontal layout

### Saved-method carousel

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet saved-method carousel in LTR](ltr/payment-sheet-horizontal/main-carousel.png) | ![PaymentSheet saved-method carousel in RTL](rtl/payment-sheet-horizontal/main-carousel.png) |

**Android behavior:** Begin the logical collection at RTL leading on the right and advance through payment options from right to left.

### Edit carousel

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet carousel edit mode in LTR](ltr/payment-sheet-horizontal/edit-carousel.png) | ![PaymentSheet carousel edit mode in RTL](rtl/payment-sheet-horizontal/edit-carousel.png) |

**Android behavior:** Preserve the mirrored collection order in edit mode and keep each edit/remove affordance attached to the same logical card.

### Add a new method from the carousel

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![PaymentSheet add method carousel in LTR](ltr/payment-sheet-horizontal/new-method-carousel.png) | ![PaymentSheet add method carousel in RTL](rtl/payment-sheet-horizontal/new-method-carousel.png) |

**Android behavior:** Mirror the carousel's starting edge and payment-method order; the back indicator points right in RTL while card-entry data remains LTR.

## CustomerSheet

### Main saved-method screen

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![CustomerSheet main screen in LTR](ltr/customer-sheet/main.png) | ![CustomerSheet main screen in RTL](rtl/customer-sheet/main.png) |

**Android behavior:** Mirror the saved-method collection, navigation actions, and row contents without reflecting payment artwork.

### Edit saved methods

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![CustomerSheet edit mode in LTR](ltr/customer-sheet/edit.png) | ![CustomerSheet edit mode in RTL](rtl/customer-sheet/edit.png) |

**Android behavior:** Reverse the collection's logical horizontal flow and place edit/remove controls on semantic edges.

### Add card

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![CustomerSheet add card in LTR](ltr/customer-sheet/add-card.png) | ![CustomerSheet add card in RTL](rtl/customer-sheet/add-card.png) |

**Android behavior:** Mirror navigation and the payment-method collection, use natural form alignment, and keep card-number entry internally LTR.

### Manage bank account

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![CustomerSheet bank management in LTR](ltr/customer-sheet/manage-bank.png) | ![CustomerSheet bank management in RTL](rtl/customer-sheet/manage-bank.png) |

**Android behavior:** Mirror labels, action controls, and navigation while preserving the readable ordering of account digits.

### Manage card

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![CustomerSheet card management in LTR](ltr/customer-sheet/manage-card.png) | ![CustomerSheet card management in RTL](rtl/customer-sheet/manage-card.png) |

**Android behavior:** Mirror the card-management chrome and label/value relationships; do not mirror card brand or numeric data.

### Card scanner

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![CustomerSheet card scanner in LTR](ltr/customer-sheet/card-scanner.png) | ![CustomerSheet card scanner in RTL](rtl/customer-sheet/card-scanner.png) |

**Android behavior:** Place scanner dismissal at RTL trailing on the left and leave the scan target itself unchanged.

## PaymentSheet.FlowController

### Merchant-hosted checkout

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![FlowController host checkout in LTR](ltr/flow-controller/host-checkout.png) | ![FlowController host checkout in RTL](rtl/flow-controller/host-checkout.png) |

**Android behavior:** Mirror the merchant-owned row composition and selected-payment-method affordance so the host UI and Stripe UI share one reading direction.

### Payment-method picker

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![FlowController payment-method picker in LTR](ltr/flow-controller/payment-method-picker.png) | ![FlowController payment-method picker in RTL](rtl/flow-controller/payment-method-picker.png) |

**Android behavior:** Place icons at RTL leading, selection/accessory controls at RTL trailing, and mirror the sheet navigation action.

### Card form

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![FlowController card form in LTR](ltr/flow-controller/card-form.png) | ![FlowController card form in RTL](rtl/flow-controller/card-form.png) |

**Android behavior:** Use the same form rules as PaymentSheet: mirrored semantic placement with LTR numeric entry and a right-pointing RTL back indicator.

## EmbeddedPaymentElement

### Flat rows with radio controls

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![EmbeddedPaymentElement flat radio rows in LTR](ltr/embedded-payment-element/flat-radio.png) | ![EmbeddedPaymentElement flat radio rows in RTL](rtl/embedded-payment-element/flat-radio.png) |

**Android behavior:** Move payment artwork to RTL leading on the right and selection controls to the corresponding semantic edge without mirroring the artwork.

### Floating-button rows

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![EmbeddedPaymentElement floating rows in LTR](ltr/embedded-payment-element/floating-button.png) | ![EmbeddedPaymentElement floating rows in RTL](rtl/embedded-payment-element/floating-button.png) |

**Android behavior:** Reverse the logical row sequence and mirror each button's internal icon/text arrangement.

### Flat rows with checkmarks

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![EmbeddedPaymentElement flat checkmark rows in LTR](ltr/embedded-payment-element/flat-checkmark.png) | ![EmbeddedPaymentElement flat checkmark rows in RTL](rtl/embedded-payment-element/flat-checkmark.png) |

**Android behavior:** Put artwork and labels on RTL leading and keep the selected-state checkmark on its semantic accessory edge.

### Flat rows with disclosure indicators

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![EmbeddedPaymentElement disclosure rows in LTR](ltr/embedded-payment-element/flat-disclosure.png) | ![EmbeddedPaymentElement disclosure rows in RTL](rtl/embedded-payment-element/flat-disclosure.png) |

**Android behavior:** In RTL, the default disclosure indicator sits on the physical left and points left toward forward navigation. Stripe's known directional chevron mirrors; merchant-supplied custom artwork does not.

### Card form

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![EmbeddedPaymentElement card form in LTR](ltr/embedded-payment-element/card-form.png) | ![EmbeddedPaymentElement card form in RTL](rtl/embedded-payment-element/card-form.png) |

**Android behavior:** Mirror the expanded row and form chrome while preserving LTR ordering for card number, expiration, CVC, and postal-code input.

### Card scanner

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![EmbeddedPaymentElement card scanner in LTR](ltr/embedded-payment-element/card-scanner.png) | ![EmbeddedPaymentElement card scanner in RTL](rtl/embedded-payment-element/card-scanner.png) |

**Android behavior:** Place the close control on RTL trailing at the physical left; do not mirror the camera viewport.

## Link

### Standalone payment-method picker

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Link standalone picker in LTR](ltr/link/standalone-picker.png) | ![Link standalone picker in RTL](rtl/link/standalone-picker.png) |

**Android behavior:** Move Done to RTL trailing on the left, place row artwork at RTL leading on the right, and point forward accessories left.

### Verification

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Link verification in LTR](ltr/link/verification.png) | ![Link verification in RTL](rtl/link/verification.png) |

**Android behavior:** Place the Link logo at RTL leading and Close at RTL trailing. Email addresses and one-time-code digits retain their intrinsic LTR ordering.

### Wallet — collapsed

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Collapsed Link wallet in LTR](ltr/link/wallet-collapsed.png) | ![Collapsed Link wallet in RTL](rtl/link/wallet-collapsed.png) |

**Android behavior:** Mirror the Link header, email row, payment summary, overflow control, and expand/collapse affordance while leaving brand/card art unchanged.

### Wallet — expanded

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Expanded Link wallet in LTR](ltr/link/wallet-expanded.png) | ![Expanded Link wallet in RTL](rtl/link/wallet-expanded.png) |

**Android behavior:** Apply the same semantic row structure throughout success, failure, insufficient-funds, delayed, and other unusual saved-method states.

### Update card

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Link update card in LTR](ltr/link/update-card.png) | ![Link update card in RTL](rtl/link/update-card.png) |

**Android behavior:** Mirror the Link navigation header, field labels/accessories, country selector, and default control while preserving card data order.

### Add card

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Link add card in LTR](ltr/link/add-card.png) | ![Link add card in RTL](rtl/link/add-card.png) |

**Android behavior:** The back arrow moves to RTL leading on the right and points right; form content mirrors semantically while numbers and card-brand marks remain LTR/unmirrored.

## Checkout components

### Cart with items

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Checkout cart in LTR](ltr/checkout-components/checkout-cart.png) | ![Checkout cart in RTL](rtl/checkout-components/checkout-cart.png) |

**Android behavior:** Mirror the close control, item image/details/price columns, shipping row, express buttons, and checkout CTA contents. Prices keep their natural symbol-and-number ordering.

### Shipping address form

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Shipping address form in LTR](ltr/checkout-components/shipping-address-form.png) | ![Shipping address form in RTL](rtl/checkout-components/shipping-address-form.png) |

**Android behavior:** Mirror navigation and field accessories and use natural label/placeholder alignment. Latin addresses and postal codes remain internally LTR.

### Address autocomplete

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Address autocomplete in LTR](ltr/checkout-components/address-autocomplete.png) | ![Address autocomplete in RTL](rtl/checkout-components/address-autocomplete.png) |

**Android behavior:** Put Back at RTL leading on the right and align result rows to RTL leading while preserving the LTR order of Latin street addresses. Result availability is live and can vary independently of layout.

### Currency selector — collapsed details

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Currency selector with collapsed details in LTR](ltr/checkout-components/currency-selector.png) | ![Currency selector with collapsed details in RTL](rtl/checkout-components/currency-selector.png) |

**Android behavior:** Reverse the logical currency-option order, mirror cart sections and summary label/value columns, and keep flags and formatted prices unmirrored. The details link remains attached to the logical end of the English exchange-rate sentence.

### Currency selector — expanded details

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Currency selector with expanded details in LTR](ltr/checkout-components/currency-selector-expanded.png) | ![Currency selector with expanded details in RTL](rtl/checkout-components/currency-selector-expanded.png) |

**Android behavior:** Expanded explanatory text uses natural alignment inside the mirrored cart. “Hide details” stays at the end of the sentence rather than being manually moved to a physical edge. Conversion values are live and can differ slightly between captures.

## Payment-method-specific states

### AU BECS mandate

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![AU BECS mandate in LTR](ltr/payment-method-states/au-becs-mandate.png) | ![AU BECS mandate in RTL](rtl/payment-method-states/au-becs-mandate.png) |

**Android behavior:** Use natural alignment for mandate/legal text and mirror navigation and field layout; BSB, account, and other numeric input remains LTR.

### Instant Debits incentive

| LTR — `master` | RTL — final implementation |
| --- | --- |
| ![Instant Debits incentive in LTR](ltr/payment-method-states/instant-debits-incentive.png) | ![Instant Debits incentive in RTL](rtl/payment-method-states/instant-debits-incentive.png) |

**Android behavior:** Mirror the incentive row, bank artwork/text relationship, and navigation while using natural alignment for the Instant Debits legal copy.

## Production behavior represented by this audit

The final iOS implementation makes the following explicit production changes; the remaining mirroring visible above is inherited from semantic UIKit layout:

| Area | Explicit iOS behavior |
| --- | --- |
| Payment-method collections | Horizontal collections flip and begin at the RTL leading edge. |
| PaymentSheet navigation | Back chevrons flip for RTL. |
| Card scanner | Close uses semantic trailing placement. |
| Row accessories | Stripe's default forward/disclosure chevrons flip for RTL. |
| EmbeddedPaymentElement disclosure rows | The default disclosure artwork flips; custom merchant artwork is deliberately untouched. |
| Link navigation | Logo, title boundaries, close/back controls, and back artwork use RTL-aware semantic placement. |
| Link verification and signup | Header close placement and legal-copy alignment become directional/natural. |
| AU BECS and Instant Debits | Mandate/legal copy uses natural text alignment. |

## Exclusions and follow-up

- Financial Connections web content is out of scope. This audit covers native entry surfaces only; hosted web content owns its own RTL behavior.
- Arabic translations and Arabic snapshot tests are out of scope until translations are available.
- iPad and landscape are out of scope for this effort.
- VoiceOver traversal and Dynamic Type require separate interactive smoke checks; static screenshots do not prove either behavior.
- Backend-specific permutations that do not exercise a different directional layout are represented by the equivalent retained screen rather than duplicated.
- The audit establishes visual parity for the production RTL diff and its affected native MPE surfaces. It is not a claim that every possible backend error, merchant customization, or localization string has been exercised.
