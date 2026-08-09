# PR7 final-stack RTL screen gallery

This gallery records the complete RTL presentation of the stacked PaymentSheet
changes at `060107a1b44` (`codex/rtl-embedded-payment-element`). It was captured
by manually operating the production PaymentSheet Example app with Apple's RTL
pseudolanguage launch arguments.

| | Value |
| --- | --- |
| Branch | `codex/rtl-embedded-payment-element` |
| Commit | `060107a1b44487c0fb740f69e126319a884005b6` |
| Simulator | iPhone 12 mini, iOS 18.0 (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`) |
| App | `com.stripe.PaymentSheet-Example` |
| Launch | `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES` |
| Capture | Native Simulator framebuffer via `xcrun simctl io ... screenshot` |

The images contain only the simulated device display. They do not include the
macOS pointer, Simulator controls, or desktop chrome.

The gallery contains 36 screenshots. “Horizontal” and “vertical” refer to the
PaymentSheet payment-method layouts, not device orientation. Financial
Connections is intentionally excluded because its web/native flow is outside
the scope of this RTL stack.

## PaymentSheet — vertical layout

| Main | Saved methods | Edit saved methods |
| --- | --- | --- |
| ![Vertical PaymentSheet main screen](payment-sheet-vertical/01-main-saved-bank.jpg) | ![Vertical saved-method selector](payment-sheet-vertical/02-saved-methods.jpg) | ![Vertical saved-method editor](payment-sheet-vertical/03-manage-saved-methods.jpg) |

| Manage bank | Manage card | Add card |
| --- | --- | --- |
| ![Manage a saved bank account](payment-sheet-vertical/04-manage-bank.jpg) | ![Manage a saved card](payment-sheet-vertical/05-manage-card.jpg) | ![Vertical add-card form](payment-sheet-vertical/06-card-form.jpg) |

| Card scanner |
| --- |
| ![RTL card scanner](payment-sheet-vertical/07-card-scanner.jpg) |

## PaymentSheet — horizontal layout

| Saved-method carousel | Edit carousel | New-method carousel and form |
| --- | --- | --- |
| ![Horizontal PaymentSheet carousel](payment-sheet-horizontal/01-main-carousel.jpg) | ![Horizontal PaymentSheet edit mode](payment-sheet-horizontal/02-edit-carousel.jpg) | ![Horizontal new-method carousel and card form](payment-sheet-horizontal/03-new-card-method-carousel.jpg) |

## PaymentSheet.FlowController

| Example checkout | Saved-method picker | Edit saved methods |
| --- | --- | --- |
| ![FlowController example checkout](flow-controller/00-example-checkout.jpg) | ![FlowController saved-method picker](flow-controller/01-saved-picker.jpg) | ![FlowController edit mode](flow-controller/02-edit-saved-methods.jpg) |

| New-method picker | Card form |
| --- | --- |
| ![FlowController new-method picker](flow-controller/03-new-method-picker.jpg) | ![FlowController card form](flow-controller/04-card-form.jpg) |

## CustomerSheet

| Main | Edit | Manage card |
| --- | --- | --- |
| ![CustomerSheet main screen](customer-sheet/01-main.jpg) | ![CustomerSheet edit mode](customer-sheet/02-edit.jpg) | ![CustomerSheet saved-card editor](customer-sheet/03-manage-card.jpg) |

| Manage bank | Add card |
| --- | --- |
| ![CustomerSheet saved-bank editor](customer-sheet/04-manage-bank.jpg) | ![CustomerSheet add-card form](customer-sheet/05-add-card.jpg) |

## Link

| Sign in | Verification | Wallet |
| --- | --- | --- |
| ![Link sign-in screen](link/00-sign-in.jpg) | ![Link verification screen](link/01-verification.jpg) | ![Link wallet](link/02-wallet.jpg) |

| Expanded wallet | Update card | Standalone picker |
| --- | --- | --- |
| ![Expanded Link wallet](link/03-wallet-expanded.jpg) | ![Link update-card form](link/04-update-card.jpg) | ![Link standalone payment-method picker](link/05-standalone-picker.jpg) |

| Add card |
| --- |
| ![Link standalone add-card form](link/06-add-card.jpg) |

## EmbeddedPaymentElement

| Floating rows | Flat rows with radio | Flat rows with checkmark |
| --- | --- | --- |
| ![EPE floating-button rows](embedded-payment-element/01-floating.jpg) | ![EPE flat rows with RTL radio controls](embedded-payment-element/02-flat-radio.jpg) | ![EPE flat rows with RTL checkmarks](embedded-payment-element/03-flat-checkmark.jpg) |

| Flat rows with disclosure | Card form |
| --- | --- |
| ![EPE flat rows with RTL disclosure indicators](embedded-payment-element/04-flat-disclosure.jpg) | ![EPE card-form presentation](embedded-payment-element/05-card-form.jpg) |

## Checkout components

| Address form | Address autocomplete |
| --- | --- |
| ![RTL shipping-address form](checkout-components/01-address-form.jpg) | ![RTL address-autocomplete results](checkout-components/02-address-autocomplete.jpg) |

| Currency Selector — GBP | Currency Selector — USD |
| --- | --- |
| ![RTL Currency Selector with GBP selected](checkout-components/03-currency-selector-gbp.jpg) | ![RTL Currency Selector with USD selected](checkout-components/04-currency-selector-usd.jpg) |
