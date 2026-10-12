# Deferred confirmation credentials

Base: upstream/master 430531df0a0. Existing isolated worktree; implementation proceeds in this task as requested.

## Contract

Merchants can collect payment details using their original client, then return a client secret and explicit confirmation credentials from a new deferred handler. Existing String-returning handlers remain source compatible. Credentials are scoped to one confirmation attempt; no mutation of shared clients or configured payment handlers. A nil override preserves existing behavior. An explicit publishable key with nil Stripe account clears the original account header; a supplied account selects that account.

Expose IntentConfiguration.ConfirmationResult and distinct `confirmHandlerWithPaymentMethod` and `confirmHandlerWithConfirmationToken` initializers/properties returning it. Internally adapt legacy handlers to the same result. Validate overrides before network use, without logging keys. Preserve app info, beta headers, transport and endpoint configuration on the new client.

For changed credentials, the merchant must clone/attach the selected payment method to the destination intent before client confirmation (or confirm on the server). Validate the attached payment method using existing ID/type/fingerprint rules, and use its ID instead of resending the original ID. Never persist a destination-account ID as the original customer's default. Confirmation tokens are account scoped: changed credentials require server confirmation; don't resend a token from the source account.

Apple Pay must retain its original collection client and use a separate attempt-scoped confirmation client. Its existing lack of arbitrary next-action support remains unchanged. Do not claim Apple Pay handles 3DS challenges.

## Implementation and validation

1. Add credential/result and handler compatibility tests, observe missing API failure, then implement public API and internal adapters.
2. Route deferred PM and CT retrieval through attempt credentials; create an isolated STPPaymentHandler preserving 3DS customization and redirect simulation. Verify client/server PaymentIntent and SetupIntent paths, attached clone validation, invalid overrides and callback errors.
3. Wire Apple Pay's separate confirmation client and attached PM selection without affecting collection or retries. Verify both delegate routes.
4. Add network-header tests using existing HTTP stubs and real handlers: original-key collection, selected-key retrieval/confirmation, Stripe-Account clearing/replacement, server-confirmed terminal states, redirects/refresh, 3DS authentication/completion/cancellation, failures and retry isolation. Use deterministic fixtures, no live charges.
5. Run focused tests, owning module regression tests, relevant StripePayments handler tests, format/lint and API compatibility inspection. Preserve first failures and report exact environmental blockers and any untested live/backend/UI paths.

Sources: https://docs.stripe.com/connect/direct-charges-multiple-accounts and https://docs.stripe.com/connect/authentication. Clones have distinct IDs; changing credentials does not transfer payment methods, customers, or tokens.

## Implemented edge cases

| Case | Behavior |
| --- | --- |
| Existing String callback / no credential override | Original client and behavior remain intact, including throw-only trailing closure source compatibility. |
| Explicit key with nil account | Clears the source Stripe-Account header. |
| Explicit key with account | Applies both values to retrieval, confirmation, redirects, and 3DS. |
| Changed credentials and client confirmation | Requires an attached matching destination payment method; confirms using its ID. |
| Changed credentials and server confirmation | Validates the selected payment method and handles next actions with the destination client. |
| Confirmation token with changed credentials | Requires server confirmation; source token is never submitted for destination client confirmation. |
| Saved payment method with Radar challenge data | Requires server confirmation when credentials change; never silently drops account-scoped fraud data. |
| Dashboard user key to publishable key | Requires server confirmation to preserve MOTO classification. |
| Recollected card CVC | Preserved in destination client confirmation. |
| Destination customer/default payment method | Does not save a destination ID into the source customer's defaults. |
| Apple Pay retry | Clears per-attempt overrides before collecting again using original credentials. |
| 3DS challenge cancellation / redirect callback | Parent handler forwards to the active isolated handler; error cleanup permits retry. |
| Test redirect simulation | Uses the confirmation client's test/live mode, not the global client. |

New tests use the real API clients and payment handlers with stubbed HTTP responses, asserting request credentials and payment method IDs. Native 3DS authentication is exercised with test certificates; completion/cancellation use real handler endpoints and a fake challenge transaction. This does not replace a live Connect backend or physical-device Apple Pay/3DS acceptance test.

## Verification results

All simulator runs used the existing iPhone 12 mini on iOS 18.0 (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`) through `ci_scripts/run_tests.rb`, sourcing the ignored `.stripe-ios-config` first to bypass the runner's unavailable default runtime selection. No simulator resets, new devices, or runtime installations were performed.

- Full PaymentSheet suite: 2,164 tests, 2,155 passed and 9 failed. All 21 new tests passed. Result: `/private/tmp/deferred-credentials-paymentsheet.xcresult`.
- Clean upstream/master comparison: reran the exact nine failures from an independent `git archive HEAD` checkout. Seven reproduced: two Apple Pay Later availability assertions, one URL-decoding assertion, and four ambiguous-layout snapshot assertions. The two Link attestation tests passed. Result: `/private/tmp/deferred-credentials-baseline.xcresult`.
- Existing shared payment handler, stubbed 3DS, redirect refresh, and Apple Pay context tests: 27 passed, no failures. Result: `/private/tmp/deferred-credentials-handlers.xcresult`.
- Final feature-branch rerun: all 21 new credential tests, including the final malformed-account/Radar/MOTO assertions, and both intermittent Link tests passed (23/23). Result: `/private/tmp/deferred-credentials-final.xcresult`. The two Link failures did not reproduce in focused runs on either branch; the full-suite run remains recorded as failed.
- Pinned SwiftLint 0.63.2: zero violations across all ten changed/new Swift files; the final added validation assertions also passed strict lint. `git diff --check` passed.
- Independent production review found no remaining concrete correctness blocker after addressing account-scoped Radar data and Dashboard MOTO handling.

The full-suite Link failures were a five-second captcha timeout and a missing web-flow delegate assertion in unchanged code. Failure diagnostics are exported at `/private/tmp/deferred-credentials-diagnostics`; layout failures occurred before image comparison and provided no failure screenshot attachments. Existing snapshot references were not changed.

## Payment handler reuse audit

The original handler is reused when no override is returned. With an override, `withAPIClient` retains a separate handler for the whole asynchronous attempt and forwards parent cancellation/URL callbacks to it. The original client's credentials are never changed. The child preserves 3DS customization, redirect simulation, the redirect shim, and the analytics client.

Confirmation creates action parameters that retain the selected API client. Intent refresh, polling, 3DS authentication, challenge completion, and source cancellation use that action client; server-provided 3DS publishable-key overrides remain supported. PaymentSheet, FlowController, EmbeddedPaymentElement, and Link initialize their parent handlers using their configuration's API client.

The audit found and reproduced an overlap bug: the same-client fast path bypassed the scope guard, and same-client attempts did not reserve the handler during retrieval. A per-handler scope flag now rejects overlapping original/override combinations before any second operation starts and is released on success or error. The regression covers all four combinations. Additional coverage checks real declined confirmations followed by another override and then original credentials for both intent types, global-lock cleanup, and child-handler release after an error.

Validation: the overlap test failed before the fix (`/private/tmp/handler-reuse-red.xcresult`). After the fix, all 45 credential/deferred-flow tests and all 27 shared-handler regressions passed (`/private/tmp/handler-reuse-regression.xcresult` and `/private/tmp/handler-reuse-shared.xcresult`). Strict lint and whitespace checks passed. Independent review found no remaining concrete correctness issue in the production change. The full PaymentSheet suite was not repeated for this focused fix; its prior baseline/flaky failures remain documented above.

### Follow-up: connected account omitted from hosted confirmation challenge

Owner/repository: **unknown**, recorded at the user's request. This is a pre-existing limitation of the `intent_confirmation_challenge` web flow, separate from the native 3DS flows.

- The iOS bridge in `StripePayments/StripePayments/Source/Internal/IntentConfirmationChallengeViewController.swift` returns only `clientSecret` and `publishableKey` from `getInitParams`.
- The hosted page at `https://b.stripecdn.com/mobile-confirmation-challenge/assets/index.html?v=1` currently loads `index-cbgnpl90.js`, whose initialization calls `window.Stripe(params.publishableKey)` without `stripeAccount`.
- Native challenge cancellation and subsequent intent retrieval still use the correctly configured API client, but the web challenge does not receive its connected-account header value.
- Follow-up requires both the iOS bridge to send the account and the hosted page to pass it to Stripe.js. Sending an extra native field alone would not fix the current hosted page. Validate with a real connected-account challenge after both changes.
- No hosted-page or bridge changes were made during this audit. An account-specific publishable key without a Stripe-Account header does not have this particular omission.
