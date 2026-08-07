# RTL Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove that PaymentSheet, CustomerSheet, FlowController, EmbeddedPaymentElement, Link, Checkout components, and Financial Connections render and operate correctly in right-to-left interfaces without adding Arabic translations or test-only production behavior.

**Architecture:** Test RTL at three boundaries. UIKit snapshot tests receive an inherited `UITraitCollection(layoutDirection: .rightToLeft)` through a real view-controller/window hierarchy; SwiftUI snapshot tests receive `\.environment(\.layoutDirection, .rightToLeft)`; a small UI-test layer launches the PaymentSheet Example app with Apple's `-AppleTextDirection YES` pseudolanguage argument. Component tests remain fast, product snapshots verify pixels, and UI smoke tests cover the real launch and presentation lifecycle.

**Tech Stack:** XCTest, iOSSnapshotTestCase, UIKit trait collections, SwiftUI environment values, XCUIAutomation, PaymentSheet Example, `ci_scripts/run_tests.rb`.

## Global Constraints

- Do not add Arabic, Hebrew, or other translations. Use existing English strings and fixed English/Latin fixtures.
- Follow Apple's [Right-to-left HIG](https://developer.apple.com/design/human-interface-guidelines/right-to-left): mirror interface structure, align one- and two-line content with the interface, and preserve the order of numbers and directional data.
- Use Apple's RTL pseudolanguage behavior for app-level testing. On iOS the supported launch override is `-AppleTextDirection YES`.
- Run focused tests on the available iPhone 12 mini with iOS 18.0 through `ci_scripts/run_tests.rb`; do not run the full suite for this work.
- Store committed reference images in `Tests/ReferenceImages_64` and use the repository snapshot-recording workflow.
- Do not expose private production properties solely so a test can assert an implementation detail.
- Do not recursively set `semanticContentAttribute` on private descendants. Supply layout direction through a trait environment at the product or component boundary.
- Preserve explicit `.forceLeftToRight` semantics for card numbers, phone numbers, one-time codes, and other directional data.
- Each test must pass on its branch and fail when the corresponding production fix is temporarily removed. A test that passes both versions is not regression coverage.
- Keep snapshots deterministic: fixed values, fixed sizes, no live dates, no animations in flight, and no network dependency.

## Evidence and Industry Pattern

- Apple recommends the Right-to-Left Pseudolanguage before translations exist: <https://developer.apple.com/documentation/xcode/preparing-your-interface-for-localization>
- Apple documents `-AppleTextDirection YES` for testing RTL layout on iOS: <https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/TestingYourInternationalApp/TestingYourInternationalApp.html>
- UIKit provides `UITraitCollection(layoutDirection:)` specifically for a layout-direction trait: <https://developer.apple.com/documentation/uikit/uitraitcollection/init%28layoutdirection%3A%29>
- Point-Free SnapshotTesting applies supplied traits by hosting the subject in a window and calling `setOverrideTraitCollection`: <https://github.com/pointfreeco/swift-snapshot-testing/blob/59a99c458de4d2dee580529b61b4f78dca7b7fa6/Sources/SnapshotTesting/Common/View.swift#L1022-L1064>
- Square's Paralayout records LTR and RTL variants with `.image(traits: .init(layoutDirection: .rightToLeft))`: <https://github.com/square/Paralayout/blob/36bc9c9606a4ae2f1c176d61f915519968397e59/Example/ParalayoutSnapshotTests/ViewDistributionSnapshotTests.swift#L115-L124>
- Sentry SnapshotPreviews treats RTL, Dynamic Type, landscape, and accessibility as explicit snapshot variants: <https://github.com/getsentry/SnapshotPreviews#variants>

## Test Ownership by Stacked PR

| Order | Branch | Required proof |
|---:|---|---|
| 1 | `codex/rtl-ui-foundations` | Shared trait-hosting utility; full-width text and picker fields with English values; floating-placeholder animation origin; removal of tests and access changes that inspect private fields |
| 2 | `codex/rtl-paymentsheet` | PaymentSheet list/form, saved methods, edit/delete, error, mandate, and unusual payment-method states |
| 3 | `codex/rtl-checkout-components` | Currency selector, address autocomplete, and Financial Connections native surfaces |
| 4 | `codex/rtl-link` | Link signup, verification, inline verification, wallet, navigation, error, and mandate states |
| 5 | `codex/rtl-customer-sheet` | CustomerSheet empty, saved-card, add, edit, delete, and responsive variants |
| 6 | `codex/rtl-flow-controller` | FlowController saved screen, direct-to-card form, errors, and responsive variants |
| 7 | `codex/rtl-embedded-payment-element` | All four EPE row styles, selection/disclosure behavior, form presentation, and responsive variants |

---

### Task 1: Replace Recursive RTL Mutation with a UIKit Trait Host

**Files:**
- Modify: `StripeCore/StripeCoreTestUtils/STPSnapshotTestCase.swift`
- Modify: `StripeCore/StripeCoreTestUtils/Categories/UIView+StripeCoreTestingUtils.swift`
- Test: `StripeUICore/StripeUICoreTests/Snapshot/Elements/AddressSectionElementSnapshotTest.swift`

**Interfaces:**
- Consumes: `UITraitCollection(layoutDirection:)`, `UIViewController.setOverrideTraitCollection(_:forChild:)`, `UIWindow`.
- Produces: `STPSnapshotTestCase.hostForSnapshot(_:size:traits:) -> UIView` overloads for `UIViewController` and `UIView`; retained windows until `tearDown()`.

- [ ] **Step 1: Change the address snapshot to request an inherited RTL trait**

```swift
let traits = UITraitCollection(layoutDirection: .rightToLeft)
let hostedView = hostForSnapshot(
    sut.view,
    size: CGSize(width: 300, height: 400),
    traits: traits
)
XCTAssertEqual(hostedView.traitCollection.layoutDirection, .rightToLeft)
XCTAssertEqual(hostedView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
STPSnapshotVerifyView(hostedView)
```

Remove the test's direct assignment to `semanticContentAttribute`.

- [ ] **Step 2: Run the test and verify that the missing helper fails to compile**

```bash
ci_scripts/run_tests.rb --test StripeUICoreTests/AddressSectionElementSnapshotTest/testRightToLeftWithLeftToRightValues
```

Expected: compilation fails because `hostForSnapshot(_:size:traits:)` does not exist.

- [ ] **Step 3: Add the trait-hosting helper**

Add retained window storage to `STPSnapshotTestCase` and implement both overloads:

```swift
private var snapshotWindows: [UIWindow] = []

public func hostForSnapshot(
    _ viewController: UIViewController,
    size: CGSize,
    traits: UITraitCollection
) -> UIView {
    let host = UIViewController()
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    host.view.frame = window.bounds

    host.addChild(viewController)
    host.setOverrideTraitCollection(traits, forChild: viewController)
    host.view.addSubview(viewController.view)
    viewController.view.frame = host.view.bounds
    viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    viewController.didMove(toParent: host)

    window.rootViewController = host
    window.isHidden = false
    window.setNeedsLayout()
    window.layoutIfNeeded()
    snapshotWindows.append(window)
    return viewController.view
}

public func hostForSnapshot(
    _ view: UIView,
    size: CGSize,
    traits: UITraitCollection
) -> UIView {
    let viewController = UIViewController()
    viewController.view = view
    return hostForSnapshot(viewController, size: size, traits: traits)
}
```

In `tearDown()`, hide and release every retained window before calling `super.tearDown()`.

- [ ] **Step 4: Remove recursive forcing**

Delete `forceRightToLeftLayout()` and `forceRightToLeftLayoutIfUnspecified()` from `UIView+StripeCoreTestingUtils.swift`. Keep `autosizeHeight(width:)` unchanged.

- [ ] **Step 5: Run the focused snapshot test**

```bash
ci_scripts/run_tests.rb --test StripeUICoreTests/AddressSectionElementSnapshotTest/testRightToLeftWithLeftToRightValues
```

Expected: PASS; the trait and effective layout direction assertions both report RTL.

- [ ] **Step 6: Commit the shared test infrastructure on PR 1**

```bash
git add StripeCore/StripeCoreTestUtils/STPSnapshotTestCase.swift \
  StripeCore/StripeCoreTestUtils/Categories/UIView+StripeCoreTestingUtils.swift \
  StripeUICore/StripeUICoreTests/Snapshot/Elements/AddressSectionElementSnapshotTest.swift
git commit -m "Improve RTL snapshot test environment"
```

### Task 2: Make Foundation Tests Assert Customer-Visible Behavior

**Files:**
- Modify: `StripeUICore/StripeUICoreTests/Unit/Elements/TextFieldElementTest.swift`
- Modify: `StripeUICore/StripeUICoreTests/Unit/Elements/DropdownFieldElementTest.swift`
- Modify: `StripeUICore/StripeUICoreTests/Snapshot/Elements/AddressSectionElementSnapshotTest.swift`
- Modify: `StripeUICore/StripeUICore/Source/Elements/PickerField/PickerFieldView.swift`
- Review: `StripePaymentsUI/StripePaymentsUITests/STPPaymentCardTextFieldSnapshotTests.swift`
- Review: `StripePaymentsUI/StripePaymentsUI/Source/Internal/UI/Views/CardBrandView.swift`

**Interfaces:**
- Consumes: `hostForSnapshot(_:size:traits:)` from Task 1.
- Produces: one full-width field snapshot that proves labels, entered values, dropdown values, icons, and chevrons appear on the correct side without revealing private controls.

- [ ] **Step 1: Remove property-level alignment tests**

Delete tests whose only assertion is `textField.textAlignment == .right`. Remove `private(set)` from `PickerFieldView.textField` if no production caller needs that visibility.

- [ ] **Step 2: Use fixed mixed-direction fixtures in the address snapshot**

Use these values without translating labels:

```swift
name: "Nick Porter"
email: "nick@example.com"
addressLine1: "510 Townsend St"
city: "San Francisco"
postalCode: "94103"
country: "United States"
```

The snapshot must be wide enough that alignment is visible; do not autosize a field to the width of its text.

- [ ] **Step 3: Run the foundation snapshot with production alignment present**

```bash
ci_scripts/run_tests.rb --test StripeUICoreTests/AddressSectionElementSnapshotTest/testRightToLeftWithLeftToRightValues
```

Expected: PASS; short values and the country dropdown occupy the trailing/right side while Latin glyph order remains unchanged.

- [ ] **Step 4: Perform the TextFieldView negative control**

Temporarily remove the RTL alignment behavior from `TextFieldView.swift`, rerun the command from Step 3, and verify a snapshot mismatch showing at least one ordinary text value on the wrong side. Restore the production change immediately.

Expected: FAIL without the production change; PASS after restoration.

- [ ] **Step 5: Perform the PickerFieldView negative control**

Temporarily remove the RTL alignment behavior from `PickerFieldView.swift`, rerun the command from Step 3, and verify that `United States` moves to the wrong side in the full-width dropdown. Restore the production change immediately.

Expected: FAIL without the production change; PASS after restoration.

- [ ] **Step 6: Prove or remove the floating-placeholder production change**

Record a focused snapshot with the placeholder floating and the field hosted through the RTL trait environment. Temporarily restore the old initialization-time anchor-point calculation and rerun it.

Expected: if the snapshot does not fail or show the animation/layout origin on the wrong side, remove the `FloatingPlaceholderTextFieldView` production change from PR 1.

- [ ] **Step 7: Prove or remove the CardBrandView production change**

Locate a PaymentSheet product surface that renders the changed CBC indicator. If no PaymentSheet, CustomerSheet, FlowController, EPE, or Link product boundary exercises it, delete the CardBrandView change and its synthetic snapshot from PR 1.

- [ ] **Step 8: Commit the foundation test cleanup**

```bash
git add StripeUICore StripePaymentsUI Tests/ReferenceImages_64
git commit -m "Test RTL fields through rendered behavior"
```

### Task 3: Migrate Core PaymentSheet Snapshots to Trait-Driven RTL

**Files:**
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/PaymentSheetSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/PaymentSheetVerticalViewControllerSnapshotTest.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/SavedPaymentOptionsViewControllerSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/UpdatePaymentMethodViewControllerSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/EmbeddedFormViewControllerSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 1's snapshot host and `UITraitCollection(traitsFrom:)`.
- Produces: PaymentSheet snapshots for base phone, landscape, iPad, accessibility Dynamic Type, saved methods, editing/deletion, errors, mandates, and unusual payment methods.

- [ ] **Step 1: Define the four product trait variants in each existing verification helper**

```swift
let rtl = UITraitCollection(layoutDirection: .rightToLeft)
let dynamicType = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraLarge)
let iPad = UITraitCollection(userInterfaceIdiom: .pad)
let traits = UITraitCollection(traitsFrom: [rtl, dynamicType, iPad])
```

Only combine traits required by that named test; do not make every snapshot exercise every dimension.

- [ ] **Step 2: Replace every `forceRightToLeftLayout()` call in these files**

Host the subject with the RTL trait before snapshot verification. Assert both `traitCollection.layoutDirection` and `effectiveUserInterfaceLayoutDirection` are RTL.

- [ ] **Step 3: Run the base PaymentSheet RTL snapshot**

```bash
ci_scripts/run_tests.rb --test StripePaymentSheetTests/PaymentSheetSnapshotTests/testPaymentSheetRightToLeft
```

Expected: PASS.

- [ ] **Step 4: Run the error, mandate, and unusual-state snapshot**

```bash
ci_scripts/run_tests.rb --test StripePaymentSheetTests/PaymentSheetVerticalViewControllerSnapshotTest/testDisplaysErrorMandateAndUnusualPaymentMethodsRightToLeft
```

Expected: PASS for the list, list-with-mandate, and form snapshots.

- [ ] **Step 5: Run saved-method editing coverage**

```bash
ci_scripts/run_tests.rb --test StripePaymentSheetTests/SavedPaymentOptionsViewControllerSnapshotTests/test_all_saved_pms_editing_right_to_left
```

Expected: PASS; edit/delete affordances mirror and payment-brand artwork remains readable.

- [ ] **Step 6: Run a production negative control**

Temporarily remove one PR 2 layout fix that the base snapshot crosses, rerun Step 3, verify a pixel mismatch, then restore the fix.

- [ ] **Step 7: Commit PR 2 test migration**

```bash
git add StripePaymentSheet/StripePaymentSheetTests Tests/ReferenceImages_64
git commit -m "Test PaymentSheet with inherited RTL traits"
```

### Task 4: Cover Checkout Components and Financial Connections

**Files:**
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Checkout/CheckoutCurrencySelectorViewSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/AutoCompleteViewControllerSnapshotTests.swift`
- Modify: `StripeFinancialConnections/StripeFinancialConnectionsTests/FinancialConnectionsRTLSnapshotTests.swift`
- Modify: `StripeFinancialConnections/StripeFinancialConnectionsTests/RightToLeftLayoutTests.swift`

**Interfaces:**
- Consumes: Task 1's UIKit trait host.
- Produces: trait-driven snapshots for currency selection, address results, Financial Connections phone/landscape/iPad/Dynamic Type surfaces, and targeted geometry tests for direction-preserving controls.

- [ ] **Step 1: Replace recursive semantic forcing in all four files**

Use `UITraitCollection(layoutDirection: .rightToLeft)` in the view-controller host. Keep explicit `.forceLeftToRight` assertions only for controls whose data order must remain LTR.

- [ ] **Step 2: Run currency selector and autocomplete snapshots**

```bash
ci_scripts/run_tests.rb \
  --test StripePaymentSheetTests/CheckoutCurrencySelectorViewSnapshotTests/testRightToLeft \
  --test StripePaymentSheetTests/AutoCompleteViewControllerSnapshotTests/testAutoCompleteViewController_rightToLeft
```

Expected: PASS; disclosure indicators, selected currency, search results, errors, and navigation affordances mirror.

- [ ] **Step 3: Run the Financial Connections RTL snapshot matrix**

```bash
ci_scripts/run_tests.rb --scheme StripeFinancialConnections \
  --test StripeFinancialConnectionsTests/FinancialConnectionsRTLSnapshotTests
```

Expected: four passing snapshots covering phone, landscape, iPad, and accessibility Dynamic Type.

- [ ] **Step 4: Perform one checkout and one Financial Connections negative control**

Temporarily remove the corresponding product fix for each surface, rerun its focused test, require a failure, and restore the fix.

- [ ] **Step 5: Commit PR 3 coverage**

```bash
git add StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Checkout \
  StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/AutoCompleteViewControllerSnapshotTests.swift \
  StripeFinancialConnections/StripeFinancialConnectionsTests \
  Tests/ReferenceImages_64
git commit -m "Test checkout and bank linking in RTL"
```

### Task 5: Cover Link's Complete Signup and Verification Paths

**Files:**
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Link/LinkSignUpViewControllerSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Link/LinkVerificationViewSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Link/LinkInlineVerificationViewSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Link/WalletViewControllerSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Link/LinkNavigationBarSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 1's UIKit trait host; SwiftUI `layoutDirection` environment.
- Produces: Link snapshots covering suggestion, signup, OTP verification, errors, wallet, mandate, and navigation.

- [ ] **Step 1: Use the correct environment for each implementation technology**

UIKit Link screens use the trait host. SwiftUI Link screens use:

```swift
let rootView = verificationView.environment(\.layoutDirection, .rightToLeft)
let sut = UIHostingController(rootView: rootView)
```

- [ ] **Step 2: Run Link RTL snapshots**

```bash
ci_scripts/run_tests.rb \
  --test StripePaymentSheetTests/LinkSignUpViewControllerSnapshotTests/testRightToLeftWithEmailSuggestion \
  --test StripePaymentSheetTests/LinkVerificationViewSnapshotTests/testRightToLeftModalWithErrorAndInput \
  --test StripePaymentSheetTests/WalletViewControllerSnapshotTests/testRightToLeftWithErrorAndMandate
```

Expected: PASS; email and OTP glyph order remains LTR while controls and one-line labels align with the RTL interface.

- [ ] **Step 3: Perform a Link navigation negative control**

Temporarily remove the PR 4 navigation-direction fix, run `LinkNavigationBarSnapshotTests/testRightToLeft`, verify a mismatch, and restore the fix.

- [ ] **Step 4: Commit PR 4 coverage**

```bash
git add StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/Link Tests/ReferenceImages_64
git commit -m "Test complete Link flows in RTL"
```

### Task 6: Cover CustomerSheet Product States

**Files:**
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/CustomerSheetSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 1's trait host.
- Produces: CustomerSheet RTL snapshots for empty and saved-card states plus phone, landscape, iPad, and accessibility Dynamic Type variants.

- [ ] **Step 1: Replace direct semantic forcing with trait hosting**

Create the CustomerSheet controller normally, host it with an RTL trait, and snapshot the entire sheet rather than an isolated row.

- [ ] **Step 2: Run the CustomerSheet matrix**

```bash
ci_scripts/run_tests.rb \
  --test StripePaymentSheetTests/CustomerSheetSnapshotTests/testRightToLeft \
  --test StripePaymentSheetTests/CustomerSheetSnapshotTests/testOneSavedCardPMRightToLeft \
  --test StripePaymentSheetTests/CustomerSheetSnapshotTests/testRightToLeftDynamicType
```

Expected: PASS.

- [ ] **Step 3: Perform a CustomerSheet negative control**

Temporarily remove a PR 5 row or navigation fix, rerun the saved-card snapshot, require a mismatch, and restore the fix.

- [ ] **Step 4: Commit PR 5 coverage**

```bash
git add StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/CustomerSheetSnapshotTests.swift \
  Tests/ReferenceImages_64/StripePaymentSheetTests.CustomerSheetSnapshotTests.*
git commit -m "Test CustomerSheet product states in RTL"
```

### Task 7: Cover FlowController Product States

**Files:**
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/PaymentSheetFlowControllerViewControllerSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 1's trait host.
- Produces: FlowController saved-screen and direct-to-card snapshots with responsive variants and error coverage.

- [ ] **Step 1: Include RTL in the existing trait override**

```swift
let traits = UITraitCollection(traitsFrom: [
    UITraitCollection(layoutDirection: .rightToLeft),
    UITraitCollection(horizontalSizeClass: .compact),
    UITraitCollection(verticalSizeClass: .regular),
])
```

Apply it with `host.setOverrideTraitCollection(traits, forChild: sut)` and remove recursive forcing.

- [ ] **Step 2: Run saved and direct-to-card tests**

```bash
ci_scripts/run_tests.rb \
  --test StripePaymentSheetTests/PaymentSheetFlowControllerViewControllerSnapshotTests/testSavedScreen_cardRightToLeft \
  --test StripePaymentSheetTests/PaymentSheetFlowControllerViewControllerSnapshotTests/testDirectToCardScanRightToLeft
```

Expected: PASS.

- [ ] **Step 3: Perform the FlowController negative control**

Temporarily remove one PR 6 controller-level fix, rerun the saved-card test, require a mismatch, and restore the fix.

- [ ] **Step 4: Commit PR 6 coverage**

```bash
git add StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/PaymentSheetFlowControllerViewControllerSnapshotTests.swift \
  Tests/ReferenceImages_64/StripePaymentSheetTests.PaymentSheetFlowControllerViewControllerSnapshotTests.*
git commit -m "Test FlowController product states in RTL"
```

### Task 8: Cover All EmbeddedPaymentElement Row Styles

**Files:**
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/EmbeddedPaymentMethodsViewSnapshotTests.swift`
- Modify: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/EmbeddedPaymentElementSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 1's trait host.
- Produces: four row-style snapshots and full EPE snapshots for phone, landscape, iPad, and accessibility Dynamic Type.

- [ ] **Step 1: Host all EPE snapshots with RTL traits**

Remove direct semantic forcing. Test these row styles independently:

```text
flat radio
flat checkmark
flat disclosure
floating
```

- [ ] **Step 2: Run the row-style tests**

```bash
ci_scripts/run_tests.rb \
  --test StripePaymentSheetTests/EmbeddedPaymentMethodsViewSnapshotTests/testEmbeddedPaymentMethodsView_flatRadioRightToLeft \
  --test StripePaymentSheetTests/EmbeddedPaymentMethodsViewSnapshotTests/testEmbeddedPaymentMethodsView_flatWithCheckmarkRightToLeft \
  --test StripePaymentSheetTests/EmbeddedPaymentMethodsViewSnapshotTests/testEmbeddedPaymentMethodsView_flatWithDisclosureRightToLeft \
  --test StripePaymentSheetTests/EmbeddedPaymentMethodsViewSnapshotTests/testEmbeddedPaymentMethodsView_floatingRightToLeft
```

Expected: four passing snapshots with consistent trailing alignment and correct accessory placement.

- [ ] **Step 3: Run the EPE responsive matrix**

```bash
ci_scripts/run_tests.rb \
  --test StripePaymentSheetTests/EmbeddedPaymentElementSnapshotTests/testRightToLeft \
  --test StripePaymentSheetTests/EmbeddedPaymentElementSnapshotTests/testRightToLeftLandscape \
  --test StripePaymentSheetTests/EmbeddedPaymentElementSnapshotTests/testRightToLeftIPad \
  --test StripePaymentSheetTests/EmbeddedPaymentElementSnapshotTests/testRightToLeftDynamicType
```

Expected: PASS.

- [ ] **Step 4: Perform one row-style and one full-element negative control**

Temporarily remove the associated PR 7 fixes, verify the focused snapshots fail, and restore the fixes.

- [ ] **Step 5: Commit PR 7 coverage**

```bash
git add StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/EmbeddedPaymentMethodsViewSnapshotTests.swift \
  StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/EmbeddedPaymentElementSnapshotTests.swift \
  Tests/ReferenceImages_64/StripePaymentSheetTests.EmbeddedPayment*
git commit -m "Test EmbeddedPaymentElement variants in RTL"
```

### Task 9: Add Launch-Time RTL UI Smoke Tests

**Files:**
- Create: `Example/PaymentSheet Example/PaymentSheetUITest/PaymentSheetRTLUITests.swift`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example-Shard2.xctestplan`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example-Shard3.xctestplan`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example-Shard4.xctestplan`

**Interfaces:**
- Consumes: `PaymentSheetUITestCase`, `PaymentSheetTestPlaygroundSettings`, `loadPlayground(_:_:)`.
- Produces: app-level RTL smoke coverage that exercises the same initialization path as manual QA.

- [ ] **Step 1: Create an opt-in RTL UI-test class**

```swift
final class PaymentSheetRTLUITests: PaymentSheetUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        app.launchArguments += ["-AppleTextDirection", "YES"]
    }

    func testPaymentSheetCardFormInRightToLeftPseudolanguage() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.customerMode = .new
        settings.uiStyle = .paymentSheet
        loadPlayground(app, settings)

        app.buttons["Present PaymentSheet"].waitForExistenceAndTap()
        app.buttons["Card"].waitForExistenceAndTap()

        XCTAssertTrue(app.textFields["Card number"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Country or region"].exists)
        XCTAssertTrue(app.buttons["Pay $50.99"].exists)
    }
}
```

- [ ] **Step 2: Add one EPE smoke method to the same class**

Load settings with `settings.uiStyle = .embedded`, present the embedded element, select Card, and assert the card and country fields are present and hittable.

- [ ] **Step 3: Run only the two RTL UI tests**

Assign `PaymentSheetRTLUITests` to shard 1 by adding it to `skippedTests` in shard plans 2, 3, and 4. Then verify the sharding configuration:

```bash
ci_scripts/check_paymentsheet_test_sharding.rb
```

Expected: PASS; the new class is enabled in exactly one shard.

- [ ] **Step 4: Run only the two RTL UI tests**

```bash
ci_scripts/run_tests.rb --scheme "PaymentSheet Example" \
  --test PaymentSheetUITest/PaymentSheetRTLUITests
```

Expected: two passing tests. The app remains in English while UIKit initializes and presents its hierarchy as RTL.

- [ ] **Step 5: Attach diagnostic screenshots on failure**

Use `XCTAttachment(screenshot: app.screenshot())`, name it with the failing surface, and set `lifetime = .keepAlways` inside the failure path. Do not commit UI-test screenshots as golden references; the product snapshot tests own pixel comparisons.

- [ ] **Step 6: Commit UI smoke coverage**

```bash
git add "Example/PaymentSheet Example/PaymentSheetUITest/PaymentSheetRTLUITests.swift" \
  "Example/PaymentSheet Example/PaymentSheet Example-Shard2.xctestplan" \
  "Example/PaymentSheet Example/PaymentSheet Example-Shard3.xctestplan" \
  "Example/PaymentSheet Example/PaymentSheet Example-Shard4.xctestplan"
git commit -m "Add launch-time RTL UI smoke tests"
```

### Task 10: Final Focused Verification and Manual QA

**Files:**
- Review: `Tests/ReferenceImages_64`
- Review: `Tests/RTLManualQA`
- Review: all production files changed by `master...codex/rtl-embedded-payment-element`

**Interfaces:**
- Consumes: all preceding tasks.
- Produces: a review-ready evidence matrix for the seven stacked PRs.

- [ ] **Step 1: Run each branch's focused test group**

Use the exact commands in Tasks 2–9 on the iOS 18.0 iPhone 12 mini. Record pass/fail and the `.xcresult` path for each branch.

- [ ] **Step 2: Inspect every changed reference image**

Verify:

```text
navigation and disclosure affordances mirror
one-line labels and values align consistently with the RTL interface
emails, card numbers, phone numbers, ZIP codes, and OTP digits retain their order
brand logos and non-directional artwork do not mirror
errors and mandates remain readable
edit/delete affordances remain associated with the correct row
landscape, iPad, and accessibility Dynamic Type do not clip
```

- [ ] **Step 3: Run the playground in Apple's RTL pseudolanguage**

```bash
xcrun simctl launch 79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1 com.stripe.PaymentSheet-Example \
  -AppleTextDirection YES
```

Manually inspect PaymentSheet, CustomerSheet, FlowController, EPE, Link, Checkout currency/address surfaces, and Financial Connections.

- [ ] **Step 4: Verify VoiceOver order manually**

Confirm focus follows the visual RTL order without reversing the internal order of card digits, phone digits, OTP digits, or email text.

- [ ] **Step 5: Audit test-to-production causality**

For every production change, identify the focused test that fails without it. Remove any production change that has no real product caller or no observable failing test. Remove any test-only access modifier left behind by implementation-detail assertions.

- [ ] **Step 6: Record the translation follow-up boundary**

When Stripe-provided RTL translations arrive, add a separate locale matrix using at least one Arabic locale and one Hebrew locale. That later work validates fonts, bidi paragraphs, localized numerals, currency/date formatting, keyboards, and translated string expansion; it is not part of these seven UI-support PRs.

- [ ] **Step 7: Commit final test corrections on the branch that owns each surface**

Use a separate commit per stacked PR and do not amend existing production commits.

## Definition of Done

- Every RTL snapshot receives direction from UIKit traits or the SwiftUI environment, not recursive descendant mutation.
- Every app-level RTL test launches with `-AppleTextDirection YES` before PaymentSheet code runs.
- Every changed production behavior has a focused test that fails when that behavior is removed.
- No test requires Arabic translations.
- No private production property is widened solely for a test.
- The seven PRs collectively cover all four EPE row styles; currency and address selection; complete Link signup and verification; errors, mandates, edit/delete, and unusual payment methods; iPad, landscape, accessibility Dynamic Type, and VoiceOver; CustomerSheet; FlowController; PaymentSheet; and Financial Connections.
- Focused tests pass on the iOS 18.0 iPhone 12 mini and all committed snapshots have been visually reviewed.
