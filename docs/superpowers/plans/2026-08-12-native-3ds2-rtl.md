# Native 3DS2 Right-to-Left Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Stripe's native 3DS2 challenge UI follow RTL reading order only where current UIKit behavior is insufficient.

**Architecture:** Preserve UIKit-provided navigation, text alignment, whitelist, progress, and logo behavior. Fix the shared custom horizontal layout primitive with semantic Auto Layout attributes, mark only the directional expandable chevron for automatic RTL flipping, and preserve the superclass text-field geometry that reserves clear-button space.

**Tech Stack:** Objective-C, UIKit Auto Layout, XCTest/FBSnapshotTestCase test target, Stripe3DS2DemoUI, iOS Simulator.

## Global Constraints

- Base the branch on upstream `master` at `1e451705acae6da740400affb9c3139381957563`.
- Use the existing iOS 18.0 iPhone 12 mini (`79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1`).
- Do not add Arabic translations or Arabic snapshot references.
- Do not modify ACS-hosted HTML or Financial Connections web content.
- Do not mirror issuer or payment-network logo image content.
- Run focused Stripe3DS2 tests and a demo build, not the full Stripe iOS suite.
- Push only `codex/rtl-native-3ds2` to `worldofnick/stripe-ios`; do not open an upstream PR.

---

### Task 1: Add focused RTL regression tests

**Files:**
- Modify: `Stripe3DS2/Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests.m`

**Interfaces:**
- Consumes: `STDSStackView`, `STDSExpandableInformationView`, and `STDSTextField` from the production target.
- Produces: three focused regression tests that fail independently on unmodified master.

- [ ] **Step 1: Import the three native view headers**

```objc
#import "STDSExpandableInformationView.h"
#import "STDSStackView.h"
#import "STDSTextChallengeView.h"
```

- [ ] **Step 2: Add a failing semantic horizontal-order test**

```objc
- (void)testHorizontalStackViewUsesRightToLeftOrder {
    STDSStackView *stackView = [[STDSStackView alloc] initWithAlignment:STDSStackViewLayoutAxisHorizontal];
    stackView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    stackView.frame = CGRectMake(0, 0, 100, 40);

    UIView *firstView = [UIView new];
    UIView *secondView = [UIView new];
    [stackView addArrangedSubview:firstView];
    [stackView addArrangedSubview:secondView];
    [NSLayoutConstraint activateConstraints:@[
        [firstView.widthAnchor constraintEqualToConstant:40],
        [secondView.widthAnchor constraintEqualToConstant:60],
    ]];

    [stackView layoutIfNeeded];

    XCTAssertGreaterThan(CGRectGetMinX(firstView.frame), CGRectGetMinX(secondView.frame));
}
```

- [ ] **Step 3: Add a failing directional-chevron test**

```objc
- (void)testExpandableInformationChevronFlipsForRightToLeftLayout {
    STDSExpandableInformationView *view = [STDSExpandableInformationView new];
    UIImageView *titleImageView = [view valueForKey:@"titleImageView"];

    XCTAssertTrue(titleImageView.image.flipsForRightToLeftLayoutDirection);
}
```

- [ ] **Step 4: Add a failing code-entry geometry test**

```objc
- (void)testTextFieldEditingRectDoesNotOverlapRightToLeftClearButton {
    STDSTextField *textField = [STDSTextField new];
    textField.frame = CGRectMake(0, 0, 320, 44);
    textField.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    textField.clearButtonMode = UITextFieldViewModeAlways;
    textField.text = @"123456";

    CGRect editingRect = [textField editingRectForBounds:textField.bounds];
    CGRect clearButtonRect = [textField clearButtonRectForBounds:textField.bounds];

    XCTAssertFalse(CGRectIntersectsRect(editingRect, clearButtonRect));
}
```

- [ ] **Step 5: Run the three tests and verify RED**

Run:

```bash
xcodebuild test \
  -project Stripe3DS2/Stripe3DS2.xcodeproj \
  -scheme Stripe3DS2DemoUI \
  -destination 'id=79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1,arch=arm64' \
  -only-testing:Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests/testHorizontalStackViewUsesRightToLeftOrder \
  -only-testing:Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests/testExpandableInformationChevronFlipsForRightToLeftLayout \
  -only-testing:Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests/testTextFieldEditingRectDoesNotOverlapRightToLeftClearButton \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all three tests execute and fail their assertions on master.

- [ ] **Step 6: Commit the regression tests**

```bash
git add Stripe3DS2/Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests.m
git commit -m "Test native 3DS2 RTL layout"
```

### Task 2: Make the custom horizontal stack semantic

**Files:**
- Modify: `Stripe3DS2/Stripe3DS2/STDSStackView.m`
- Test: `Stripe3DS2/Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests.m`

**Interfaces:**
- Consumes: `UIView.semanticContentAttribute` and leading/trailing Auto Layout attributes.
- Produces: `STDSStackView` horizontal arranged subviews that follow the effective interface layout direction.

- [ ] **Step 1: Replace horizontal physical attributes**

Within `_applyHorizontalConstraints`, rename the physical-edge constraint variables and use:

```objc
NSLayoutAttributeLeading
NSLayoutAttributeTrailing
```

The first visible arranged subview must constrain its leading edge to the stack's leading edge. Each subsequent view's leading edge must constrain to the previous view's trailing edge. The last visible arranged subview must retain the stack's trailing constraint. Do not change `_applyVerticalConstraints`.

- [ ] **Step 2: Run the horizontal-order test and verify GREEN**

Run the Task 1 command with only `testHorizontalStackViewUsesRightToLeftOrder`.

Expected: PASS.

- [ ] **Step 3: Commit the shared layout fix**

```bash
git add Stripe3DS2/Stripe3DS2/STDSStackView.m
git commit -m "Use semantic layout for native 3DS2 rows"
```

### Task 3: Make the expandable chevron directional

**Files:**
- Modify: `Stripe3DS2/Stripe3DS2/STDSExpandableInformationView.m`
- Test: `Stripe3DS2/Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests.m`

**Interfaces:**
- Consumes: `UIImage.imageFlippedForRightToLeftLayoutDirection`.
- Produces: a collapsed chevron that automatically mirrors without changing non-directional images.

- [ ] **Step 1: Prepare only the Chevron asset for RTL flipping**

After loading and applying template rendering mode, call:

```objc
chevronImage = [chevronImage imageFlippedForRightToLeftLayoutDirection];
```

Do not flip issuer, payment-network, selection, warning, or universal-symbol images.

- [ ] **Step 2: Run the directional-chevron test and verify GREEN**

Run the Task 1 command with only `testExpandableInformationChevronFlipsForRightToLeftLayout`.

Expected: PASS.

- [ ] **Step 3: Commit the chevron fix**

```bash
git add Stripe3DS2/Stripe3DS2/STDSExpandableInformationView.m
git commit -m "Mirror native 3DS2 disclosure chevrons"
```

### Task 4: Preserve clear-button space in verification-code entry

**Files:**
- Modify: `Stripe3DS2/Stripe3DS2/STDSTextChallengeView.m`
- Test: `Stripe3DS2/Stripe3DS2DemoUITests/STDSChallengeResponseViewControllerSnapshotTests.m`

**Interfaces:**
- Consumes: `UITextField` superclass text and editing rectangles.
- Produces: existing eight-point horizontal text padding applied inside UIKit's accessory-aware rect.

- [ ] **Step 1: Apply the margin to superclass rectangles**

```objc
- (CGRect)textRectForBounds:(CGRect)bounds {
    return CGRectInset([super textRectForBounds:bounds], kTextFieldMargin, 0);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    return CGRectInset([super editingRectForBounds:bounds], kTextFieldMargin, 0);
}
```

- [ ] **Step 2: Run the code-entry geometry test and verify GREEN**

Run the Task 1 command with only `testTextFieldEditingRectDoesNotOverlapRightToLeftClearButton`.

Expected: PASS.

- [ ] **Step 3: Run all three focused regression tests together**

Run the complete Task 1 command.

Expected: 3 tests, 0 failures.

- [ ] **Step 4: Commit the text-field fix**

```bash
git add Stripe3DS2/Stripe3DS2/STDSTextChallengeView.m
git commit -m "Keep native 3DS2 code clear button unobstructed"
```

### Task 5: Verify changed behavior in the Simulator

**Files:**
- Create: `readme-images/rtl-simulator-evidence/native-3ds2/README.md`
- Create: four `before-*.png` images under `readme-images/rtl-simulator-evidence/native-3ds2/`
- Create: four matching `after-*.png` images under `readme-images/rtl-simulator-evidence/native-3ds2/`

**Interfaces:**
- Consumes: `Stripe3DS2DemoUI` launched with forced-RTL arguments.
- Produces: cursor-free native framebuffer evidence for only the four visibly changed states.

- [ ] **Step 1: Build and install the branch demo**

```bash
xcodebuild build \
  -project Stripe3DS2/Stripe3DS2.xcodeproj \
  -scheme Stripe3DS2DemoUI \
  -configuration Debug \
  -destination 'id=79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1,arch=arm64' \
  -derivedDataPath /private/tmp/rtl-native-3ds2-derived \
  CODE_SIGNING_ALLOWED=NO
xcrun simctl install 79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1 \
  /private/tmp/rtl-native-3ds2-derived/Build/Products/Debug-iphonesimulator/Stripe3DS2DemoUI.app
xcrun simctl launch --terminate-running-process \
  79CA7DB2-0A4B-4EC4-B93C-D28E8C9458F1 \
  com.stripe.Stripe3DS2DemoUI \
  -AppleTextDirection YES \
  -NSForceRightToLeftWritingDirection YES
```

- [ ] **Step 2: Operate the demo and capture matched after states**

Use the native demo to capture single-select, expanded help, OOB, and entered-code states. Save each with `xcrun simctl io … screenshot`; do not use desktop screenshots.

- [ ] **Step 3: Verify the interactions**

Confirm that selecting the second radio row updates accessibility state, expanding/collapsing help works, and entering `123456` leaves the clear button visible without overlapping the first digit.

- [ ] **Step 4: Add only meaningful evidence**

Copy the four previously captured latest-master baselines from `/private/tmp/rtl-3ds2-pr-evidence/before/` and the four branch captures into the evidence directory. Write a README that identifies base and branch SHAs and records the UIKit-provided behaviors that required no code.

- [ ] **Step 5: Commit the evidence**

```bash
git add readme-images/rtl-simulator-evidence/native-3ds2
git commit -m "Add native 3DS2 RTL Simulator evidence"
```

### Task 6: Final verification and fork delivery

**Files:**
- Verify: all branch changes relative to `1e451705acae6da740400affb9c3139381957563`
- Remove: `docs/superpowers/specs/2026-08-12-native-3ds2-rtl-design.md`
- Remove: `docs/superpowers/plans/2026-08-12-native-3ds2-rtl.md`

**Interfaces:**
- Consumes: completed production/test/evidence commits.
- Produces: a clean PR-sized branch whose net diff contains only product, focused tests, and relevant Simulator evidence.

- [ ] **Step 1: Remove internal planning artifacts from the delivered diff**

Delete the design and implementation-plan files so process documentation does not inflate the final PR diff. Commit the deletion separately.

- [ ] **Step 2: Run final focused verification**

Run the complete three-test command from Task 1 and the demo build from Task 5. Run `git diff --check` and confirm there are no localization-file changes.

- [ ] **Step 3: Audit the final diff**

Confirm the production diff is limited to:

```text
Stripe3DS2/Stripe3DS2/STDSStackView.m
Stripe3DS2/Stripe3DS2/STDSExpandableInformationView.m
Stripe3DS2/Stripe3DS2/STDSTextChallengeView.m
```

Confirm tests and the eight before/after evidence images are the only non-production additions.

- [ ] **Step 4: Push the branch to the fork**

```bash
git push -u fork codex/rtl-native-3ds2
```

- [ ] **Step 5: Verify the remote branch**

Confirm `git ls-remote fork refs/heads/codex/rtl-native-3ds2` equals the local HEAD and the working tree is clean.
