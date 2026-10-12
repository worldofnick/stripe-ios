# StripePaymentSheet iOS SDK module

PaymentSheet is a prebuilt UI that combines all the steps required to pay - collecting payment details, billing details, and confirming the payment - into a single sheet that displays on top of your app.

## Table of contents
<!-- NOTE: Use case-sensitive anchor links for docc compatibility -->
<!--ts-->
* [Features](#Features)
* [Requirements](#Requirements)
* [Getting started](#Getting-started)
   * [Integration](#Integration)
   * [Example](#Example)
* [Manual linking](#Manual-linking)

<!--te-->

## Requirements

The StripePaymentSheet module is compatible with apps targeting iOS 15.0 or above.

## Getting started

### Integration

Get started with our [📚 integration guides](https://stripe.com/docs/payments/accept-a-payment?platform=ios&ui=payment-sheet) and [example projects](/Example), or [📘 browse the SDK reference](https://stripe.dev/stripe-ios/stripe-paymentsheet/index.html) for fine-grained documentation of all the classes and methods in the SDK.

### Example

- [Prebuilt UI](Example/PaymentSheet%20Example)
  - This example demonstrates how to build a payment flow using [`PaymentSheet`](https://stripe.com/docs/payments/accept-a-payment?platform=ios), an embeddable native UI component that lets you accept [10+ payment methods](https://stripe.com/docs/payments/payment-methods/integration-options#payment-method-product-support) with a single integration.

### Select credentials during deferred confirmation

Use `confirmHandlerWithPaymentMethod` when your server selects the account that owns the intent after payment details have been collected:

```swift
let intentConfiguration = PaymentSheet.IntentConfiguration(
    mode: .payment(amount: 1099, currency: "usd"),
    confirmHandlerWithPaymentMethod: { paymentMethod, shouldSavePaymentMethod in
        // Your backend creates the intent in the destination account, cloning and
        // attaching the selected payment method there when necessary.
        let response = try await backend.createIntent(
            paymentMethodID: paymentMethod.stripeId,
            shouldSavePaymentMethod: shouldSavePaymentMethod
        )
        return .init(
            clientSecret: response.clientSecret,
            publishableKey: response.publishableKey,
            stripeAccount: response.stripeAccount
        )
    }
)
```

The returned credentials apply only to that attempt's intent retrieval, confirmation, and authentication, including redirects and 3DS. PaymentSheet, FlowController, and EmbeddedPaymentElement continue loading and collecting details with their configured API client. Apple Pay also retains its original collection credentials.

Return `.init(clientSecret: ...)` to keep the configured credentials. When you explicitly return a publishable key, a nil `stripeAccount` **clears** the account header; pass the connected account ID to send that header. Existing String-returning and deprecated completion-callback handlers continue to work without migration. Credential switching is opt-in through the new handlers.

Changing credentials does not transfer account-owned objects. For client confirmation with different credentials, your server must attach the selected payment method (or its supported clone) to the destination intent. The SDK validates the attached payment method and confirms with its destination ID. See [sharing payment methods across accounts](https://docs.stripe.com/connect/direct-charges-multiple-accounts) for supported payment methods and backend requirements. Customer objects and saved-payment-method lists remain in their original account.

`confirmHandlerWithConfirmationToken` returns the same result type. When changing credentials, confirm the intent on your server first; a token created using the original credentials is not sent to a different account. Server confirmation is also required when changing credentials for a saved payment method carrying Radar challenge data or for a Dashboard user-key flow. Recollected CVC remains supported for client confirmation. Apple Pay retains its existing intent-status and authentication limitations; this feature does not add arbitrary next-action presentation inside Apple Pay.

## Manual linking

If you link this library manually, use a version from our [releases](https://github.com/stripe/stripe-ios/releases) page and make sure to embed <ins>all</ins> of the following frameworks:
- `StripeCore.xcframework`
- `StripeUICore.xcframework`
- `Stripe3DS2.xcframework`
- `StripePayments.xcframework`
- `StripePaymentsUI.xcframework`
- `StripeApplePay.xcframework`
- `StripeFinancialConnectionsLite.xcframework`
- `StripePaymentSheet.xcframework`
