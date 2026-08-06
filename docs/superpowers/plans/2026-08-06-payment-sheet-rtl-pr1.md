# PaymentSheet RTL PR 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reusable UIKit and SwiftUI RTL test controls plus a PaymentSheet test-playground direction override that automated tests and engineers can select without changing the production SDK API.

**Architecture:** `StripeCoreTestUtils` owns a small cross-framework test direction type and root-level helpers for UIKit and SwiftUI. The PaymentSheet example app owns a separate three-state `system`/`LTR`/`RTL` setting, applies it to the example app's `UIWindow`, serializes it for UI-test launch data, and exposes it in the existing Client settings section. No PaymentSheet production model or configuration receives layout-direction state.

**Tech Stack:** Swift, UIKit, SwiftUI, XCTest/XCUITest, `StripeCoreTestUtils`, PaymentSheet Example, `ci_scripts/run_tests.rb`.

## Global Constraints

- Implement this PR fresh from `upstream/master`; do not cherry-pick or copy changes from experimental RTL branches.
- Production UI continues to inherit the host application's effective layout direction.
- Do not add a merchant-facing PaymentSheet configuration or mutate `UIAppearance`.
- Apply test overrides only at a root UIKit, SwiftUI, or playground-window boundary.
- Direction changes affect subsequently presented flows; live mutation of an already-presented flow is not supported.
- Do not add translations or production PaymentSheet RTL component fixes in this PR.
- Preserve existing LTR behavior and the ability to select the system direction.
- Before running tests, ensure `.stripe-ios-config` points `DEVICE_ID_FROM_USER_SETTINGS` to the available iOS 18.0 iPhone 12 mini. Never create, reset, or replace the simulator.
- Run focused tests through `ci_scripts/run_tests.rb`; run `ci_scripts/format_modified_files.sh` and `ci_scripts/lint_modified_files.sh` before the final commit.

---

## File Structure

- `StripeCore/StripeCoreTestUtils/StripeTestLayoutDirection.swift`: Defines the direction value shared by UIKit and SwiftUI test helpers and its framework-internal mappings.
- `StripeCore/StripeCoreTestUtils/Categories/UIView+StripeCoreTestingUtils.swift`: Applies a test direction to a UIKit root view and forces layout.
- `StripeCore/StripeCoreTestUtils/Categories/View+StripeCoreTestingUtils.swift`: Applies a test direction to a SwiftUI root through the environment.
- `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/RTLTestInfrastructureTests.swift`: Proves that both shared helpers propagate RTL to descendants.
- `Example/PaymentSheet Example/PaymentSheet Example/PaymentSheetTestPlaygroundSettings.swift`: Adds the optional, serializable three-state playground setting. The optional representation preserves decoding of old saved and deep-linked payloads.
- `Example/PaymentSheet Example/PaymentSheet Example/PlaygroundLayoutDirection.swift`: Maps the playground setting to a window semantic-content override.
- `Example/PaymentSheet Example/PaymentSheet Example/SceneDelegate.swift`: Applies launch-time direction before installing the playground root controller.
- `Example/PaymentSheet Example/PaymentSheet Example/PlaygroundController.swift`: Reapplies direction when playground settings change.
- `Example/PaymentSheet Example/PaymentSheet Example/PaymentSheetTestPlayground.swift`: Exposes the setting in the existing Client section.
- `Example/PaymentSheet Example/PaymentSheetUITest/RTLPlaygroundUITests.swift`: Verifies launch-time RTL propagation and the presence of the manual control.
- `Example/PaymentSheet Example/PaymentSheet Example-Shard2.xctestplan`, `Example/PaymentSheet Example/PaymentSheet Example-Shard3.xctestplan`, and `Example/PaymentSheet Example/PaymentSheet Example-Shard4.xctestplan`: Skip the new class outside shard 1 so CI runs it exactly once.

### Task 1: Shared UIKit and SwiftUI Test Direction Helpers

**Files:**
- Create: `StripeCore/StripeCoreTestUtils/StripeTestLayoutDirection.swift`
- Modify: `StripeCore/StripeCoreTestUtils/Categories/UIView+StripeCoreTestingUtils.swift`
- Create: `StripeCore/StripeCoreTestUtils/Categories/View+StripeCoreTestingUtils.swift`
- Create: `StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/RTLTestInfrastructureTests.swift`

**Interfaces:**
- Consumes: UIKit's `UISemanticContentAttribute` and SwiftUI's `EnvironmentValues.layoutDirection`.
- Produces: `public enum StripeTestLayoutDirection { case leftToRight, rightToLeft }`.
- Produces: `UIView.setTestLayoutDirection(_ direction: StripeTestLayoutDirection)`.
- Produces: `View.testLayoutDirection(_ direction: StripeTestLayoutDirection) -> some View`.

- [ ] **Step 1: Write the failing propagation tests**

Create `RTLTestInfrastructureTests.swift` with the following content:

```swift
import StripeCoreTestUtils
import SwiftUI
import UIKit
import XCTest

@MainActor
final class RTLTestInfrastructureTests: XCTestCase {
    func testUIKitRootOverridePropagatesToDescendants() {
        let rootView = UIView()
        let childView = UIView()
        rootView.addSubview(childView)

        rootView.setTestLayoutDirection(.rightToLeft)

        XCTAssertEqual(rootView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(childView.effectiveUserInterfaceLayoutDirection, .rightToLeft)
    }

    func testSwiftUIRootOverridePropagatesThroughEnvironment() async {
        let didObserveRTL = expectation(description: "SwiftUI observes the forced RTL environment")
        didObserveRTL.assertForOverFulfill = false
        var observedDirection: LayoutDirection?
        let reader = LayoutDirectionReader { direction in
            observedDirection = direction
            if direction == .rightToLeft {
                didObserveRTL.fulfill()
            }
        }
        let hostingController = UIHostingController(
            rootView: reader.testLayoutDirection(.rightToLeft)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = hostingController
        window.isHidden = false

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        await fulfillment(of: [didObserveRTL], timeout: 1)

        XCTAssertEqual(observedDirection, .rightToLeft)
    }
}

private struct LayoutDirectionReader: UIViewRepresentable {
    @Environment(\.layoutDirection) private var layoutDirection
    let didUpdate: (LayoutDirection) -> Void

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        didUpdate(layoutDirection)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
ci_scripts/run_tests.rb --test StripePaymentSheetTests/RTLTestInfrastructureTests
```

Expected: build failure because `StripeTestLayoutDirection`, `setTestLayoutDirection`, and `testLayoutDirection` do not exist.

- [ ] **Step 3: Define the shared test direction**

Create `StripeTestLayoutDirection.swift`:

```swift
import SwiftUI
import UIKit

public enum StripeTestLayoutDirection {
    case leftToRight
    case rightToLeft

    var semanticContentAttribute: UISemanticContentAttribute {
        switch self {
        case .leftToRight:
            return .forceLeftToRight
        case .rightToLeft:
            return .forceRightToLeft
        }
    }

    var swiftUILayoutDirection: LayoutDirection {
        switch self {
        case .leftToRight:
            return .leftToRight
        case .rightToLeft:
            return .rightToLeft
        }
    }
}
```

- [ ] **Step 4: Add the UIKit helper**

Append this method inside the existing `extension UIView` in `UIView+StripeCoreTestingUtils.swift`:

```swift
    /// Forces a root view and its descendants to use a layout direction in tests.
    public func setTestLayoutDirection(_ direction: StripeTestLayoutDirection) {
        semanticContentAttribute = direction.semanticContentAttribute
        setNeedsLayout()
        layoutIfNeeded()
    }
```

- [ ] **Step 5: Add the SwiftUI helper**

Create `View+StripeCoreTestingUtils.swift`:

```swift
import SwiftUI

extension View {
    /// Forces a SwiftUI root and its descendants to use a layout direction in tests.
    public func testLayoutDirection(_ direction: StripeTestLayoutDirection) -> some View {
        environment(\.layoutDirection, direction.swiftUILayoutDirection)
    }
}
```

- [ ] **Step 6: Run the focused tests**

Run:

```bash
ci_scripts/run_tests.rb --test StripePaymentSheetTests/RTLTestInfrastructureTests
```

Expected: both tests pass, demonstrating UIKit descendant inheritance and SwiftUI environment propagation.

- [ ] **Step 7: Commit the shared infrastructure**

```bash
git add StripeCore/StripeCoreTestUtils/StripeTestLayoutDirection.swift StripeCore/StripeCoreTestUtils/Categories/UIView+StripeCoreTestingUtils.swift StripeCore/StripeCoreTestUtils/Categories/View+StripeCoreTestingUtils.swift StripePaymentSheet/StripePaymentSheetTests/PaymentSheet/RTLTestInfrastructureTests.swift
git commit -m "Add RTL layout direction test helpers"
```

### Task 2: Serializable Playground Launch Override

**Files:**
- Modify: `Example/PaymentSheet Example/PaymentSheet Example/PaymentSheetTestPlaygroundSettings.swift`
- Create: `Example/PaymentSheet Example/PaymentSheet Example/PlaygroundLayoutDirection.swift`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example/SceneDelegate.swift`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example/PlaygroundController.swift`
- Create: `Example/PaymentSheet Example/PaymentSheetUITest/RTLPlaygroundUITests.swift`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example-Shard2.xctestplan`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example-Shard3.xctestplan`
- Modify: `Example/PaymentSheet Example/PaymentSheet Example-Shard4.xctestplan`

**Interfaces:**
- Consumes: `PaymentSheetTestPlaygroundSettings` Codable launch data and the key playground `UIWindow`.
- Produces: `PaymentSheetTestPlaygroundSettings.LayoutDirection` with `system`, `leftToRight`, and `rightToLeft` cases.
- Produces: optional `PaymentSheetTestPlaygroundSettings.layoutDirection`; a missing decoded value resolves to `.system`.
- Produces: `PlaygroundLayoutDirection.apply(_:to:)` for launch-time and settings-change application.

- [ ] **Step 1: Write the failing launch-time UI test**

Create `RTLPlaygroundUITests.swift`:

```swift
import XCTest

final class RTLPlaygroundUITests: PaymentSheetUITestCase {
    func testRightToLeftLaunchMirrorsPlaygroundHeader() {
        var settings = PaymentSheetTestPlaygroundSettings.defaultValues()
        settings.layoutDirection = .rightToLeft

        loadPlayground(app, settings)

        let resetButton = app.buttons["Reset"]
        let qrButton = app.buttons["QR"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertTrue(qrButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(resetButton.frame.midX, qrButton.frame.midX)
    }
}
```

- [ ] **Step 2: Assign the UI test class to shard 1**

Add `"RTLPlaygroundUITests"` to the alphabetized `skippedTests` array for the `PaymentSheetUITest` target in shard 2, shard 3, and shard 4. Do not add it to shard 1 or the unsharded `PaymentSheet Example.xctestplan`.

- [ ] **Step 3: Run the UI test to verify it fails**

Run:

```bash
ci_scripts/run_tests.rb --ui --test PaymentSheetUITest/RTLPlaygroundUITests/testRightToLeftLaunchMirrorsPlaygroundHeader
```

Expected: build failure because `PaymentSheetTestPlaygroundSettings` has no `layoutDirection` setting or `.rightToLeft` case.

- [ ] **Step 4: Add the backward-compatible setting model**

Add this nested type alongside `UIStyle` in `PaymentSheetTestPlaygroundSettings.swift`:

```swift
    enum LayoutDirection: String, PickerEnum {
        static var enumName: String { "Layout Direction" }

        case system
        case leftToRight = "left_to_right"
        case rightToLeft = "right_to_left"

        var displayName: String {
            switch self {
            case .system:
                return "System"
            case .leftToRight:
                return "LTR"
            case .rightToLeft:
                return "RTL"
            }
        }
    }
```

Add the optional stored property immediately after `uiStyle`:

```swift
    var layoutDirection: LayoutDirection?
```

Pass `layoutDirection: .system` immediately after `uiStyle: .paymentSheet` in `defaultValues()`. Keeping the stored property optional makes synthesized `Decodable` use `decodeIfPresent`, so existing saved and deep-linked playground payloads decode with `nil`, which has system behavior.

- [ ] **Step 5: Implement the window-level applier**

Create `PlaygroundLayoutDirection.swift`:

```swift
import UIKit

enum PlaygroundLayoutDirection {
    @MainActor
    static func apply(
        _ layoutDirection: PaymentSheetTestPlaygroundSettings.LayoutDirection?,
        to window: UIWindow
    ) {
        switch layoutDirection ?? .system {
        case .system:
            window.semanticContentAttribute = .unspecified
        case .leftToRight:
            window.semanticContentAttribute = .forceLeftToRight
        case .rightToLeft:
            window.semanticContentAttribute = .forceRightToLeft
        }
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }
}
```

- [ ] **Step 6: Apply direction before installing the deep-linked root**

Replace the body of `SceneDelegate.launchWith(base64String:windowScene:)` with:

```swift
    func launchWith(base64String: String, windowScene: UIWindowScene) {
        let settings = PaymentSheetTestPlaygroundSettings.fromBase64(
            base64: base64String,
            className: PaymentSheetTestPlaygroundSettings.self
        )!
        let paymentSheetPlayground = PaymentSheetTestPlayground(settings: settings, appearance: .default)
        let hvc = UIHostingController(rootView: paymentSheetPlayground)
        let navController = UINavigationController(rootViewController: hvc)
        let window = windowScene.windows.first!
        PlaygroundLayoutDirection.apply(settings.layoutDirection, to: window)
        window.rootViewController = navController
    }
```

- [ ] **Step 7: Reapply direction when playground settings change**

In the existing `$settings.removeDuplicates().sink` closure in `PlaygroundController.init(settings:appearance:)`, add this call before the autoreload branch:

```swift
            self?.applyLayoutDirection(newValue.layoutDirection)
```

Add this method next to `updateForcedConsumerLinkBrand(_:)`:

```swift
    private func applyLayoutDirection(
        _ layoutDirection: PaymentSheetTestPlaygroundSettings.LayoutDirection?
    ) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else {
            return
        }
        PlaygroundLayoutDirection.apply(layoutDirection, to: window)
    }
```

- [ ] **Step 8: Run the focused UI test**

Run:

```bash
ci_scripts/run_tests.rb --ui --test PaymentSheetUITest/RTLPlaygroundUITests/testRightToLeftLaunchMirrorsPlaygroundHeader
```

Expected: pass. The serialized setting is decoded at launch, the window forces RTL, and SwiftUI places the first header action (`Reset`) to the right of the last (`QR`).

- [ ] **Step 9: Commit the launch override**

```bash
git add 'Example/PaymentSheet Example/PaymentSheet Example/PaymentSheetTestPlaygroundSettings.swift' 'Example/PaymentSheet Example/PaymentSheet Example/PlaygroundLayoutDirection.swift' 'Example/PaymentSheet Example/PaymentSheet Example/SceneDelegate.swift' 'Example/PaymentSheet Example/PaymentSheet Example/PlaygroundController.swift' 'Example/PaymentSheet Example/PaymentSheetUITest/RTLPlaygroundUITests.swift' 'Example/PaymentSheet Example/PaymentSheet Example-Shard2.xctestplan' 'Example/PaymentSheet Example/PaymentSheet Example-Shard3.xctestplan' 'Example/PaymentSheet Example/PaymentSheet Example-Shard4.xctestplan'
git commit -m "Add RTL launch override to PaymentSheet playground"
```

### Task 3: Visible Playground Direction Control and Final Verification

**Files:**
- Modify: `Example/PaymentSheet Example/PaymentSheet Example/PaymentSheetTestPlayground.swift`
- Modify: `Example/PaymentSheet Example/PaymentSheetUITest/RTLPlaygroundUITests.swift`

**Interfaces:**
- Consumes: optional `PaymentSheetTestPlaygroundSettings.layoutDirection` from Task 2.
- Produces: `PaymentSheetTestPlayground.layoutDirectionBinding` that resolves missing legacy values to `.system`.
- Produces: a searchable segmented `Layout Direction` setting with `System`, `LTR`, and `RTL` options.

- [ ] **Step 1: Add the failing control-availability UI test**

Add this method to `RTLPlaygroundUITests`:

```swift
    func testLayoutDirectionControlIsAvailable() {
        let settings = PaymentSheetTestPlaygroundSettings.defaultValues()

        loadPlayground(app, settings)

        XCTAssertTrue(app.staticTexts["Layout Direction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["System"].exists)
        XCTAssertTrue(app.buttons["LTR"].exists)
        XCTAssertTrue(app.buttons["RTL"].exists)
    }
```

- [ ] **Step 2: Run the UI test to verify it fails**

Run:

```bash
ci_scripts/run_tests.rb --ui --test PaymentSheetUITest/RTLPlaygroundUITests/testLayoutDirectionControlIsAvailable
```

Expected: failure because the `Layout Direction` setting is not rendered.

- [ ] **Step 3: Add the binding for optional legacy settings**

Add this computed binding beside the existing `uiStyleBinding` in `PaymentSheetTestPlayground.swift`:

```swift
    var layoutDirectionBinding: Binding<PaymentSheetTestPlaygroundSettings.LayoutDirection> {
        Binding<PaymentSheetTestPlaygroundSettings.LayoutDirection> {
            playgroundController.settings.layoutDirection ?? .system
        } set: { newDirection in
            playgroundController.settings.layoutDirection = newDirection
        }
    }
```

- [ ] **Step 4: Render the control in Client settings**

Add this line immediately after the `uiStyleBinding` setting in `clientSettings(searchText:)`:

```swift
        SearchableSettingView(setting: layoutDirectionBinding, searchText: searchText)
```

- [ ] **Step 5: Run both playground UI tests**

Run:

```bash
ci_scripts/run_tests.rb --ui --test PaymentSheetUITest/RTLPlaygroundUITests
```

Expected: both tests pass. Launch data can force RTL, and engineers can select System, LTR, or RTL from the test playground.

- [ ] **Step 6: Run the shared-helper regression test**

Run:

```bash
ci_scripts/run_tests.rb --test StripePaymentSheetTests/RTLTestInfrastructureTests
```

Expected: both shared-helper tests pass.

- [ ] **Step 7: Format, lint, and check the diff**

Run:

```bash
ci_scripts/format_modified_files.sh
ci_scripts/lint_modified_files.sh
git diff --check
```

Expected: all commands exit successfully and formatting does not alter the intended interfaces.

- [ ] **Step 8: Manually verify the recreation contract**

In the PaymentSheet test playground on the configured iOS 18.0 iPhone 12 mini:

1. Select `RTL` under `Layout Direction`.
2. Present PaymentSheet, open Xcode's View Debugger, select the PaymentSheet root view, and confirm `effectiveUserInterfaceLayoutDirection == .rightToLeft`.
3. Dismiss PaymentSheet, select `LTR`, and present it again.
4. In the View Debugger, confirm the newly presented root reports `effectiveUserInterfaceLayoutDirection == .leftToRight`; do not require an already-presented flow to update.
5. Select `System` and confirm the example app returns to the simulator's normal direction.

- [ ] **Step 9: Commit the manual control**

```bash
git add 'Example/PaymentSheet Example/PaymentSheet Example/PaymentSheetTestPlayground.swift' 'Example/PaymentSheet Example/PaymentSheetUITest/RTLPlaygroundUITests.swift'
git commit -m "Expose RTL control in PaymentSheet playground"
```

## PR 1 Completion Checklist

- [ ] The shared UIKit helper forces direction at one root and descendants inherit it.
- [ ] The shared SwiftUI helper forces direction through the environment.
- [ ] Old playground payloads without the optional field decode with system behavior.
- [ ] UI tests can set `.rightToLeft` before app launch through serialized playground settings.
- [ ] Engineers can select System, LTR, or RTL in the PaymentSheet test playground.
- [ ] Changing the setting does not add a production API or promise live updates.
- [ ] The new UI-test class runs in exactly one CI shard.
- [ ] Focused unit and UI tests, formatting, lint, and `git diff --check` pass.

## PR 1 Implementation Audit and Evidence

- The UIKit test helper applies direction to the root and only its current unspecified subtree. Explicit semantic attributes remain subtree boundaries, including an explicit descendant whose value matches the helper's first direction. A private associated-object marker distinguishes helper-owned descendant attributes, so reapplying the opposite direction to the same root updates nested helper-owned views without taking ownership of application-authored boundaries. Views added later remain unchanged until the helper is called again.
- The window semantic override was not sufficient by itself for hosted SwiftUI playground chrome, so the playground also maps the setting into SwiftUI's `layoutDirection` environment. Testing a real newly presented PaymentSheet further showed that its separately presented hierarchy did not inherit the playground window override. The internal playground therefore passes the selection through an `@_spi(STP)` test-only direction hook on each newly built PaymentSheet or FlowController. The hook applies only to Stripe-owned presentation content roots and navigation bars; it is not merchant configuration, does not affect confirmation state, and does not promise live updates to an already-presented flow.
- Automated coverage includes shared UIKit/SwiftUI helper behavior, legacy System decoding, launch and visible System/LTR/RTL playground controls, forced-host inheritance for playground chrome, and real newly presented PaymentSheet Close-button placement after dismiss/reload/re-present transitions. Temporarily disabling only the PaymentSheet SPI application made the RTL assertion fail with the Close button at x=347 versus a 187.5 window midpoint, while the final implementation passed the same transition test.
- Manual Xcode View Debugger inspection was unavailable in the local environment. This limits only that manual inspection; the automated helper and presented-PaymentSheet assertions provide passing executable evidence.
