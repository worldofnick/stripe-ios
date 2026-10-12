import OHHTTPStubs
import OHHTTPStubsSwift
import PassKit
import Stripe3DS2
@testable @_spi(STP) import StripeApplePay
@testable @_spi(STP) import StripeCore
import StripeCoreTestUtils
@testable @_spi(STP) import StripePayments
@testable @_spi(STP) import StripePaymentSheet
@testable import StripePaymentsTestUtils
import XCTest

final class DeferredConfirmationCredentialsTests: XCTestCase {
    func testOverrideCopiesTransportAndClearsOriginalAccountWithoutMutation() throws {
        let original = STPAPIClient(publishableKey: "pk_test_original")
        original.stripeAccount = "acct_original"
        original.betas = ["test_beta=v1"]
        original.apiURL = URL(string: "https://example.test/v1")
        let result = PaymentSheet.IntentConfiguration.ConfirmationResult(
            clientSecret: "pi_test_secret_test", publishableKey: "pk_test_destination"
        )

        let client = try result.makeAPIClient(fallback: original)

        XCTAssertFalse(client === original)
        XCTAssertEqual(client.publishableKey, "pk_test_destination")
        XCTAssertNil(client.stripeAccount)
        XCTAssertEqual(client.betas, original.betas)
        XCTAssertEqual(client.apiURL, original.apiURL)
        XCTAssertTrue(client.urlSession === original.urlSession)
        XCTAssertEqual(original.publishableKey, "pk_test_original")
        XCTAssertEqual(original.stripeAccount, "acct_original")
    }

    func testNoOverrideKeepsOriginalClient() throws {
        let original = STPAPIClient(publishableKey: "pk_test_original")
        let result = PaymentSheet.IntentConfiguration.ConfirmationResult(clientSecret: "pi_test_secret_test")
        XCTAssertTrue(try result.makeAPIClient(fallback: original) === original)
    }

    func testInvalidCredentialsFailWithoutIncludingKeyInError() {
        for key in ["", "sk_test_secret", "rk_test_secret", "pk_test_", " pk_test_example", "pk_live_example\n"] {
            let result = PaymentSheet.IntentConfiguration.ConfirmationResult(clientSecret: "pi_test_secret_test", publishableKey: key)
            XCTAssertThrowsError(try result.makeAPIClient(fallback: STPAPIClient())) { error in
                if !key.isEmpty { XCTAssertFalse(String(describing: error).contains(key)) }
            }
        }
        for account in ["", "acct_", "customer_123", "acct_example\n"] {
            let result = PaymentSheet.IntentConfiguration.ConfirmationResult(clientSecret: "pi_test_secret_test", publishableKey: "pk_test_destination", stripeAccount: account)
            XCTAssertThrowsError(try result.makeAPIClient(fallback: STPAPIClient()))
        }
    }
    func testCrossAccountClientConfirmationRejectsAccountScopedFraudData() throws {
        let original = STPAPIClient(publishableKey: "pk_test_original")
        let response = PaymentSheet.IntentConfiguration.ConfirmationResult(clientSecret: "pi_test_secret_test", publishableKey: "pk_test_destination")
        let radar = STPRadarOptions(hcaptchaToken: "challenge_token")
        let pm = STPFixtures.paymentMethod()
        XCTAssertThrowsError(try response.validateClientSideConfirmation(confirmType: .saved(pm, paymentOptions: nil, clientAttributionMetadata: nil, radarOptions: radar), originalClient: original))
        radar.hcaptchaToken = nil
        radar.iosVerificationObject = ["assertion": "source_account_assertion"]
        XCTAssertThrowsError(try response.validateClientSideConfirmation(confirmType: .saved(pm, paymentOptions: nil, clientAttributionMetadata: nil, radarOptions: radar), originalClient: original))
        radar.iosVerificationObject = nil
        XCTAssertNoThrow(try response.validateClientSideConfirmation(confirmType: .saved(pm, paymentOptions: nil, clientAttributionMetadata: nil, radarOptions: radar), originalClient: original))
        radar.additionalAPIParameters = ["future_challenge": "source_account_assertion"]
        XCTAssertThrowsError(try response.validateClientSideConfirmation(confirmType: .saved(pm, paymentOptions: nil, clientAttributionMetadata: nil, radarOptions: radar), originalClient: original))
        original.publishableKey = "uk_test_original"
        XCTAssertThrowsError(try response.validateClientSideConfirmation(confirmType: .saved(pm, paymentOptions: nil, clientAttributionMetadata: nil, radarOptions: nil), originalClient: original))
    }

    func testUnchangedCredentialsPreserveFraudOptions() throws {
        let original = STPAPIClient(publishableKey: "pk_test_original")
        let response = PaymentSheet.IntentConfiguration.ConfirmationResult(clientSecret: "pi_test_secret_test")
        let radar = STPRadarOptions(hcaptchaToken: "challenge_token")
        XCTAssertNoThrow(try response.validateClientSideConfirmation(confirmType: .saved(STPFixtures.paymentMethod(), paymentOptions: nil, clientAttributionMetadata: nil, radarOptions: radar), originalClient: original))
    }

}

@MainActor
final class DeferredConfirmationCredentialNetworkTests: APIStubbedTestCase, STPAuthenticationContext {
    private let originalKey = "pk_test_original"
    private let destinationKey = "pk_test_destination"
    private var configuration: PaymentSheet.Configuration!
    private var handler: STPPaymentHandler!

    override func setUp() async throws {
        try await super.setUp()
        let client = stubbedAPIClient()
        client.publishableKey = originalKey
        client.stripeAccount = "acct_original"
        configuration = PaymentSheet.Configuration()
        configuration.apiClient = client
        configuration.returnURL = "test://stripe-redirect"
        handler = STPPaymentHandler(apiClient: client)
    }

    func authenticationPresentingViewController() -> UIViewController { UIViewController() }

    private func paymentMethod(id: String = "pm_original", fingerprint: String = "fingerprint") -> [String: Any] {
        ["id": id, "type": "card", "created": 1_652_736_692, "livemode": false,
         "card": ["fingerprint": fingerprint, "brand": "visa", "last4": "4242", "exp_month": 12, "exp_year": 2030],
        ]
    }

    private func intent(setup: Bool = false, status: String, attached: Bool = true, fingerprint: String = "fingerprint") -> [String: Any] {
        let id = setup ? "seti_test" : "pi_test"
        var result: [String: Any] = [
            "id": id, "client_secret": "\(id)_secret_test", "status": status,
            "amount": 2345, "currency": "usd", "created": 1_652_736_692,
            "livemode": false, "payment_method_types": ["card"], "confirmation_method": "automatic", "capture_method": "automatic", "usage": "off_session",
        ]
        if attached { result["payment_method"] = paymentMethod(id: "pm_destination", fingerprint: fingerprint) }
        return result
    }

    private func assertCredentials(_ request: URLRequest, key: String, account: String?) {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(key)")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Stripe-Account"), account)
    }

    private func result(setup: Bool, override: Bool = true, account: String? = nil) -> PaymentSheet.IntentConfiguration.ConfirmationResult {
        let secret = setup ? "seti_test_secret_test" : "pi_test_secret_test"
        return override ? .init(clientSecret: secret, publishableKey: destinationKey, stripeAccount: account) : .init(clientSecret: secret)
    }

    private func run(
        setup: Bool = false,
        useToken: Bool = false,
        newPaymentMethod: Bool = false,
        recollectCVC: Bool = false,
        response: PaymentSheet.IntentConfiguration.ConfirmationResult? = nil
    ) async -> PaymentSheetResult {
        let response = response ?? result(setup: setup)
        let mode: PaymentSheet.IntentConfiguration.Mode = setup ? .setup(currency: "usd") : .payment(amount: 2345, currency: "usd")
        let intentConfig: PaymentSheet.IntentConfiguration
        if useToken {
            intentConfig = .init(mode: mode, confirmHandlerWithConfirmationToken: { token in
                XCTAssertEqual(token.stripeId, "ctoken_test")
                return response
            })
        } else {
            intentConfig = .init(mode: mode, confirmHandlerWithPaymentMethod: { pm, _ in
                XCTAssertEqual(pm.stripeId, "pm_original")
                XCTAssertEqual(self.configuration.apiClient.publishableKey, self.originalKey)
                return response
            })
        }
        let savedOptions = STPConfirmPaymentMethodOptions()
        if recollectCVC {
            savedOptions.cardOptions = STPConfirmCardOptions()
            savedOptions.cardOptions?.cvc = "123"
        }
        let confirmType: PaymentSheet.ConfirmPaymentMethodType = newPaymentMethod
            ? .new(params: STPPaymentMethodParams(card: STPFixtures.paymentMethodCardParams(), billingDetails: nil, metadata: nil), paymentOptions: .init(), saveForFutureUseCheckboxState: .hidden)
            : .saved(STPPaymentMethod.decodedObject(fromAPIResponse: paymentMethod())!, paymentOptions: savedOptions, clientAttributionMetadata: nil, radarOptions: nil)
        let session = STPElementsSession.decodedObject(fromAPIResponse: [
            "payment_method_preference": ["ordered_payment_method_types": ["card"], "country_code": "US"],
            "session_id": "test", "config_id": "test",
        ])!
        let (result, _) = await PaymentSheet.routeDeferredIntentConfirmation(
            confirmType: confirmType, configuration: configuration, intentConfig: intentConfig,
            authenticationContext: self, paymentHandler: handler, isFlowController: false, elementsSession: session
        )
        XCTAssertTrue(handler.apiClient === configuration.apiClient)
        XCTAssertEqual(configuration.apiClient.publishableKey, originalKey)
        XCTAssertEqual(configuration.apiClient.stripeAccount, "acct_original")
        return result
    }

    func testClientConfirmationUsesDestinationCredentialsAndClonedPaymentMethod() async {
        for setup in [false, true] {
            for account: String? in [nil, "acct_destination"] {
                let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
                let retrieved = expectation(description: "retrieve")
                let confirmed = expectation(description: "confirm")
                stub(condition: isPath(path)) { request in
                    self.assertCredentials(request, key: self.destinationKey, account: account)
                    retrieved.fulfill()
                    return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "requires_confirmation"), statusCode: 200, headers: nil)
                }
                stub(condition: isPath(path + "/confirm")) { request in
                    self.assertCredentials(request, key: self.destinationKey, account: account)
                    XCTAssertEqual(request.queryItems?.first(where: { $0.name == "payment_method" })?.value, "pm_destination")
                    if !setup {
                        XCTAssertEqual(request.queryItems?.first(where: { $0.name == "payment_method_options[card][cvc]" })?.value, "123")
                    }
                    confirmed.fulfill()
                    return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "succeeded"), statusCode: 200, headers: nil)
                }
                let outcome = await run(setup: setup, recollectCVC: !setup, response: result(setup: setup, account: account))
                guard case .completed = outcome else { XCTFail("\(outcome)"); return }
                await fulfillment(of: [retrieved, confirmed], timeout: 3)
            }
        }
    }

    func testNewPaymentMethodIsCreatedWithOriginalCredentials() async {
        let created = expectation(description: "collect")
        stub(condition: isPath("/v1/payment_methods")) { request in
            self.assertCredentials(request, key: self.originalKey, account: "acct_original")
            created.fulfill()
            return HTTPStubsResponse(jsonObject: self.paymentMethod(), statusCode: 200, headers: nil)
        }
        stub(condition: isPath("/v1/payment_intents/pi_test")) { request in
            self.assertCredentials(request, key: self.destinationKey, account: nil)
            return HTTPStubsResponse(jsonObject: self.intent(status: "succeeded"), statusCode: 200, headers: nil)
        }
        guard case .completed = await run(newPaymentMethod: true) else { XCTFail(); return }
        await fulfillment(of: [created], timeout: 3)
    }

    func testChangedCredentialsRequireAttachedMatchingPaymentMethod() async {
        for setup in [false, true] {
            for attached in [false, true] {
                let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
                stub(condition: isPath(path)) { _ in
                    HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "requires_confirmation", attached: attached, fingerprint: "different"), statusCode: 200, headers: nil)
                }
                guard case .failed = await run(setup: setup) else { XCTFail("Must reject an absent or mismatched clone"); return }
            }
        }
    }

    func testServerConfirmationUsesDestinationCredentialsForBothIntentTypes() async {
        for setup in [false, true] {
            let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
            stub(condition: isPath(path)) { request in
                self.assertCredentials(request, key: self.destinationKey, account: "acct_destination")
                return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "succeeded"), statusCode: 200, headers: nil)
            }
            guard case .completed = await run(setup: setup, response: result(setup: setup, account: "acct_destination")) else { XCTFail(); return }
        }
    }

    func testConfirmationTokensKeepCollectionCredentialsAndRequireServerConfirmationWhenSwitching() async {
        stub(condition: isPath("/v1/confirmation_tokens")) { request in
            self.assertCredentials(request, key: self.originalKey, account: "acct_original")
            return HTTPStubsResponse(jsonObject: ["id": "ctoken_test", "created": 1_652_736_692, "livemode": false], statusCode: 200, headers: nil)
        }
        for setup in [false, true] {
            for status in ["succeeded", "requires_confirmation"] {
                let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
                stub(condition: isPath(path)) { request in
                    self.assertCredentials(request, key: self.destinationKey, account: nil)
                    return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: status), statusCode: 200, headers: nil)
                }
                let outcome = await run(setup: setup, useToken: true)
                if status == "succeeded" {
                    guard case .completed = outcome else { XCTFail("\(outcome)"); return }
                } else {
                    guard case .failed = outcome else { XCTFail("Cross-account token must not be sent to confirm"); return }
                }
            }
        }
    }

    func testRetrievalFailureDoesNotLeakCredentialsIntoRetry() async {
        let failedStub = stub(condition: isPath("/v1/payment_intents/pi_test")) { request in
            self.assertCredentials(request, key: self.destinationKey, account: nil)
            return HTTPStubsResponse(jsonObject: ["error": ["type": "invalid_request_error", "message": "No such intent"]], statusCode: 404, headers: nil)
        }
        guard case .failed = await run() else { XCTFail(); return }
        HTTPStubs.removeStub(failedStub)
        stub(condition: isPath("/v1/payment_intents/pi_test")) { request in
            self.assertCredentials(request, key: self.originalKey, account: "acct_original")
            return HTTPStubsResponse(jsonObject: self.intent(status: "succeeded"), statusCode: 200, headers: nil)
        }
        guard case .completed = await run(response: result(setup: false, override: false)) else { XCTFail(); return }
    }

    func testRedirectRefreshUsesDestinationCredentialsAndParentCallback() async {
        for setup in [false, true] {
            var returnedFromRedirect = false
            let redirected = expectation(description: "redirect")
            let refreshed = expectation(description: "refresh")
            let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
            stub(condition: isPath(path)) { request in
                self.assertCredentials(request, key: self.destinationKey, account: nil)
                var response = self.intent(setup: setup, status: returnedFromRedirect ? "succeeded" : "requires_action")
                if returnedFromRedirect { refreshed.fulfill() } else {
                    response["next_action"] = ["type": "redirect_to_url", "redirect_to_url": ["url": "https://example.test/auth", "return_url": "test://stripe-redirect"]]
                }
                return HTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
            }
            handler._redirectShim = { _, _, _ in
                redirected.fulfill()
                DispatchQueue.main.async {
                    returnedFromRedirect = true
                    XCTAssertTrue(self.handler.handleURLCallback(URL(string: "test://stripe-redirect")!))
                }
            }
            guard case .completed = await run(setup: setup) else { XCTFail(); return }
            await fulfillment(of: [redirected, refreshed], timeout: 3)
        }
    }

    func testDestinationPaymentMethodIsNotSavedAsOriginalCustomersDefault() async {
        let customerID = "cus_credentials_test"
        let previous = CustomerPaymentOption.localDefaultPaymentMethod(for: customerID)
        defer { CustomerPaymentOption.setDefaultPaymentMethod(previous, forCustomer: customerID) }
        configuration.customer = .init(id: customerID, ephemeralKeySecret: "ek_test")
        CustomerPaymentOption.setDefaultPaymentMethod(.stripeId("pm_original"), forCustomer: customerID)
        stub(condition: isPath("/v1/setup_intents/seti_test")) { _ in
            HTTPStubsResponse(jsonObject: self.intent(setup: true, status: "requires_confirmation"), statusCode: 200, headers: nil)
        }
        stub(condition: isPath("/v1/setup_intents/seti_test/confirm")) { _ in
            HTTPStubsResponse(jsonObject: self.intent(setup: true, status: "succeeded"), statusCode: 200, headers: nil)
        }
        guard case .completed = await run(setup: true) else { XCTFail(); return }
        XCTAssertEqual(CustomerPaymentOption.localDefaultPaymentMethod(for: customerID), .stripeId("pm_original"))
    }

    func testExplicitUnchangedCredentialsCanConfirmWithoutAttachedClone() async {
        stub(condition: isPath("/v1/payment_intents/pi_test")) { request in
            self.assertCredentials(request, key: self.originalKey, account: "acct_original")
            return HTTPStubsResponse(jsonObject: self.intent(status: "requires_payment_method", attached: false), statusCode: 200, headers: nil)
        }
        stub(condition: isPath("/v1/payment_intents/pi_test/confirm")) { request in
            self.assertCredentials(request, key: self.originalKey, account: "acct_original")
            XCTAssertEqual(request.queryItems?.first(where: { $0.name == "payment_method" })?.value, "pm_original")
            return HTTPStubsResponse(jsonObject: self.intent(status: "succeeded"), statusCode: 200, headers: nil)
        }
        guard case .completed = await run(response: .init(clientSecret: "pi_test_secret_test", publishableKey: originalKey, stripeAccount: "acct_original")) else { XCTFail(); return }
    }

    func testRedirectSimulationUsesTheConfirmationClientsMode() async throws {
        handler.simulateAppToAppRedirect = true
        for (key, expectedSimulation) in [("pk_live_destination", false), ("pk_test_destination", true)] {
            let client = try PaymentSheet.IntentConfiguration.ConfirmationResult(clientSecret: "pi_test_secret_test", publishableKey: key).makeAPIClient(fallback: configuration.apiClient)
            try await handler.withAPIClient(client) { child in
                XCTAssertEqual(child.simulateAppToAppRedirect, expectedSimulation)
            }
        }
    }

    private func native3DSAction(overrideKey: String? = nil) -> [String: Any] {
        let cert = """
            MIIBijCB9AIBATANBgkqhkiG9w0BAQUFADANMQswCQYDVQQGEwJVUzAgFw0yMTAz
            MjYxODQyNDVaGA8yMTIxMDMwMjE4NDI0NVowDTELMAkGA1UEBhMCVVMwgZ8wDQYJ
            KoZIhvcNAQEBBQADgY0AMIGJAoGBAL6rIW6t+8eo1exqhvYt8H1vM+TyHNNychlD
            hILw745yXZQAy9ByRG3euYEydE3SFINgWBCUuwWmkNfsZUW7Uci1PBMglBFHJrE8
            8ZvtuJgnPkqmu97a9JkyROiaqAmqoMDP95HiZG5i3a1E/QPpPyYA3VJ/El17Qqkl
            aHN32qzjAgMBAAEwDQYJKoZIhvcNAQEFBQADgYEAUhxbGQ5sQMDUqFTvibU7RzqL
            dTaFhdjTDBu5YeIbXXUrJSG2AydXRq7OacRksnQhvNYXimfcgfse46XQG7rKUCfj
            kbazRiRxMZylTz8zbePAFcVq6zxJ+RBVrv51D+/JgbCcQ50nZiocllR0J9UL8CKZ
            obaUC2OjBbSuCZwF8Ig=
            """
        let rootCA = """
            MIIBkDCB+gIJAJ3pmjFOkxTXMA0GCSqGSIb3DQEBBQUAMA0xCzAJBgNVBAYTAlVT
            MB4XDTIxMDMyNjE4NDEzMVoXDTIyMDMyNjE4NDEzMVowDTELMAkGA1UEBhMCVVMw
            gZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAKmFDGPV77Fk/wgUMwbxjQk+bpUY
            cTjNBsjK3xMaUWeE17Sry6IguO1iWaXVey9YJ1Dm83PNO/5i9nHh3gmFhEJmc55T
            g+0tZQigjTcs5/BfmWtrfPYIWqKvIJqkkHrIEJnwavAS5OFGyDArHLwUtsgJbDmW
            tIeQg3EH/8BSWR0BAgMBAAEwDQYJKoZIhvcNAQEFBQADgYEATY2aQvZZJLPgUr1/
            oDvRy6KZ6p7n3+jXF8DNvVOIaQRD4Ndk5NfStteIT5XvzfmD6QqpG3nlJ6Wy3oSP
            03KvO4GWIyP9cuP/QLaEmxJIYKwPrdxLkUHFfzyy8tN54xOWPxN4Up9gVN6pSdVk
            KWrsPfhPs3G57wir370Q69lV/8A=
            """
        var useSDK: [String: Any] = [
            "type": "stripe_3ds2_fingerprint", "directory_server_name": "none",
            "server_transaction_id": "test", "three_d_secure_2_source": "src_test",
            "directory_server_encryption": ["certificate": cert, "directory_server_id": "0000000000", "root_certificate_authorities": [rootCA]],
        ]
        if let overrideKey { useSDK["publishable_key"] = overrideKey }
        return ["type": "use_stripe_sdk", "use_stripe_sdk": useSDK]
    }

    func testNative3DSAuthenticationAndFallbackKeepDestinationCredentials() async {
        for setup in [false, true] {
            var authenticated = false
            let authenticate = expectation(description: "3DS authenticate")
            stub(condition: isPath("/v1/3ds2/authenticate")) { request in
                self.assertCredentials(request, key: self.destinationKey, account: nil)
                XCTAssertEqual(request.queryItems?.first(where: { $0.name == "source" })?.value, "src_test")
                authenticated = true
                authenticate.fulfill()
                return HTTPStubsResponse(jsonObject: ["fallback_redirect_url": "https://example.test/auth"], statusCode: 200, headers: nil)
            }
            let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
            stub(condition: isPath(path)) { request in
                self.assertCredentials(request, key: self.destinationKey, account: nil)
                var response = self.intent(setup: setup, status: authenticated ? "succeeded" : "requires_action")
                if !authenticated { response["next_action"] = self.native3DSAction() }
                return HTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
            }
            handler._redirectShim = { _, _, _ in
                DispatchQueue.main.async {
                    XCTAssertTrue(self.handler.handleURLCallback(URL(string: "test://stripe-redirect")!))
                }
            }
            let outcome = await run(setup: setup)
            guard case .completed = outcome else { XCTFail("\(outcome)"); return }
            await fulfillment(of: [authenticate], timeout: 3)
        }
    }

    func test3DSCompletionAndCancellationUseActionCredentialsIncludingServerOverride() async throws {
        for setup in [false, true] {
            for overrideKey: String? in [nil, "pk_test_3ds_override"] {
                let client = try result(setup: setup, account: "acct_destination").makeAPIClient(fallback: configuration.apiClient)
                let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
                let completed = expectation(description: "challenge_complete")
                let canceled = expectation(description: "source_cancel")
                stub(condition: isPath("/v1/3ds2/challenge_complete")) { request in
                    self.assertCredentials(request, key: overrideKey ?? self.destinationKey, account: "acct_destination")
                    completed.fulfill()
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }
                stub(condition: isPath(path)) { request in
                    self.assertCredentials(request, key: self.destinationKey, account: "acct_destination")
                    var response = self.intent(setup: setup, status: "requires_action")
                    response["next_action"] = self.native3DSAction(overrideKey: overrideKey)
                    return HTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
                }
                stub(condition: isPath(path + "/source_cancel")) { request in
                    self.assertCredentials(request, key: overrideKey ?? self.destinationKey, account: "acct_destination")
                    canceled.fulfill()
                    return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "requires_payment_method"), statusCode: 200, headers: nil)
                }
                try await handler.withAPIClient(client) { child in
                    XCTAssertFalse(child === self.handler)
                    XCTAssertTrue(child.threeDSCustomizationSettings === self.handler.threeDSCustomizationSettings)
                    var response = self.intent(setup: setup, status: "requires_action")
                    response["next_action"] = self.native3DSAction(overrideKey: overrideKey)
                    let action: STPPaymentHandlerActionParams
                    if setup {
                        action = STPPaymentHandlerSetupIntentActionParams(apiClient: client, authenticationContext: self, threeDSCustomizationSettings: child.threeDSCustomizationSettings, setupIntent: STPSetupIntent.decodedObject(fromAPIResponse: response)!, returnURL: nil) { _, _, _ in }
                    } else {
                        action = STPPaymentHandlerPaymentIntentActionParams(apiClient: client, authenticationContext: self, threeDSCustomizationSettings: child.threeDSCustomizationSettings, paymentIntent: STPPaymentIntent.decodedObject(fromAPIResponse: response)!, returnURL: nil) { _, _, _ in }
                    }
                    child.currentAction = action
                    await withCheckedContinuation { continuation in
                        child._markChallengeCompleted(withCompletion: { success, error in
                            XCTAssertTrue(success)
                            XCTAssertNil(error)
                            continuation.resume()
                        })
                    }
                    await withCheckedContinuation { continuation in
                        child._markChallengeCanceled(currentAction: action) { success, error in
                            XCTAssertTrue(success)
                            XCTAssertNil(error)
                            continuation.resume()
                        }
                    }
                    child.currentAction = nil
                }
                await fulfillment(of: [completed, canceled], timeout: 3)
            }
        }
    }

    func testParentCancelsIsolatedNative3DSChallengeAndReleasesChildAfterError() async throws {
        enum TestError: Error { case expected }
        let client = try result(setup: false).makeAPIClient(fallback: configuration.apiClient)
        do {
            try await handler.withAPIClient(client) { child in
                let transaction = CancellationTrackingTransaction()
                let action = STPPaymentHandlerPaymentIntentActionParams(apiClient: client, authenticationContext: self, threeDSCustomizationSettings: child.threeDSCustomizationSettings, paymentIntent: STPPaymentIntent.decodedObject(fromAPIResponse: self.intent(status: "requires_action"))!, returnURL: nil) { _, _, _ in }
                action.threeDS2Transaction = transaction
                child.currentAction = action
                self.handler.cancel3DS2ChallengeFlow()
                XCTAssertTrue(transaction.didCancel)
                child.currentAction = nil
                throw TestError.expected
            }
            XCTFail("Expected error")
        } catch TestError.expected { }
        try await handler.withAPIClient(client) { child in
            XCTAssertNil(child.currentAction)
            XCTAssertTrue(child.apiClient === client)
        }
        XCTAssertTrue(handler.apiClient === configuration.apiClient)
    }

    func testConcurrentCredentialScopesCannotReplaceActiveChild() async throws {
        let client = try result(setup: false).makeAPIClient(fallback: configuration.apiClient)
        try await handler.withAPIClient(client) { _ in
            do {
                try await self.handler.withAPIClient(client) { _ in XCTFail("Must not replace the active child") }
                XCTFail("Expected concurrent confirmation error")
            } catch {
                XCTAssertEqual((error as NSError).code, STPPaymentHandlerErrorCode.noConcurrentActionsErrorCode.rawValue)
            }
        }
    }

    func testApplePayConfirmationFailureThenRetryKeepsCollectionCredentials() async throws {
        configuration.applePay = .init(merchantId: "merchant_test", merchantCountryCode: "US")
        for setup in [false, true] {
            var retry = false
            let mode: PaymentSheet.IntentConfiguration.Mode = setup ? .setup(currency: "usd") : .payment(amount: 2345, currency: "usd")
            let intentConfig = PaymentSheet.IntentConfiguration(mode: mode, confirmHandlerWithPaymentMethod: { _, _ in self.result(setup: setup, override: !retry) })
            let deferredIntent = Intent.deferredIntent(intentConfig: intentConfig)
            let session = STPElementsSession._testValue()
            let context = try XCTUnwrap(STPApplePayContext.create(intent: deferredIntent, elementsSession: session, configuration: configuration, clientAttributionMetadata: .makeClientAttributionMetadata(intent: deferredIntent, elementsSession: session), completion: { _, _ in }))
            stub(condition: isPath("/v1/tokens")) { request in
                self.assertCredentials(request, key: self.originalKey, account: "acct_original")
                return HTTPStubsResponse(jsonObject: ["id": "tok_test", "type": "card", "livemode": false, "created": 1_652_736_692], statusCode: 200, headers: nil)
            }
            stub(condition: isPath("/v1/payment_methods")) { request in
                self.assertCredentials(request, key: self.originalKey, account: "acct_original")
                return HTTPStubsResponse(jsonObject: self.paymentMethod(), statusCode: 200, headers: nil)
            }
            let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
            stub(condition: isPath(path)) { request in
                self.assertCredentials(request, key: retry ? self.originalKey : self.destinationKey, account: retry ? "acct_original" : nil)
                return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "requires_confirmation"), statusCode: 200, headers: nil)
            }
            stub(condition: isPath(path + "/confirm")) { request in
                self.assertCredentials(request, key: retry ? self.originalKey : self.destinationKey, account: retry ? "acct_original" : nil)
                XCTAssertEqual(request.queryItems?.first(where: { $0.name == "payment_method" })?.value, retry ? "pm_original" : "pm_destination")
                if !retry {
                    return HTTPStubsResponse(jsonObject: ["error": ["type": "card_error", "message": "Declined"]], statusCode: 402, headers: nil)
                }
                return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "succeeded"), statusCode: 200, headers: nil)
            }
            for isRetry in [false, true] {
                retry = isRetry
                let status: PKPaymentAuthorizationStatus = await withCheckedContinuation { continuation in
                    context._completePayment(with: CredentialTestPayment()) { status, _ in continuation.resume(returning: status) }
                }
                XCTAssertEqual(status, retry ? .success : .failure)
                XCTAssertTrue(context.apiClient === configuration.apiClient)
                if retry {
                    XCTAssertNil(context.confirmationAPIClient)
                    XCTAssertNil(context.confirmationPaymentMethodID)
                }
            }
        }
    }

    func testApplePayUsesSeparateConfirmationCredentialsAndValidatedClone() async throws {
        configuration.applePay = .init(merchantId: "merchant_test", merchantCountryCode: "US")
        for setup in [false, true] {
            let mode: PaymentSheet.IntentConfiguration.Mode = setup ? .setup(currency: "usd") : .payment(amount: 2345, currency: "usd")
            let intentConfig = PaymentSheet.IntentConfiguration(mode: mode, confirmHandlerWithPaymentMethod: { _, _ in self.result(setup: setup) })
            let deferredIntent = Intent.deferredIntent(intentConfig: intentConfig)
            let session = STPElementsSession._testValue()
            let context = try XCTUnwrap(STPApplePayContext.create(intent: deferredIntent, elementsSession: session, configuration: configuration, clientAttributionMetadata: .makeClientAttributionMetadata(intent: deferredIntent, elementsSession: session), completion: { _, _ in }))
            let path = setup ? "/v1/setup_intents/seti_test" : "/v1/payment_intents/pi_test"
            stub(condition: isPath(path)) { request in
                self.assertCredentials(request, key: self.destinationKey, account: nil)
                return HTTPStubsResponse(jsonObject: self.intent(setup: setup, status: "requires_confirmation"), statusCode: 200, headers: nil)
            }
            let delegate = try XCTUnwrap(context.delegate as? ApplePayContextDelegate)
            let decoder = StripeJSONDecoder()
            let pm = try decoder.decode(StripeAPI.PaymentMethod.self, from: JSONSerialization.data(withJSONObject: paymentMethod()))
            let secret = try await delegate.applePayContext(context, didCreatePaymentMethod: pm, paymentInformation: PKPayment())
            XCTAssertEqual(secret, result(setup: setup).clientSecret)
            XCTAssertTrue(context.apiClient === configuration.apiClient)
            XCTAssertEqual(context.confirmationAPIClient?.publishableKey, destinationKey)
            XCTAssertNil(context.confirmationAPIClient?.stripeAccount)
            XCTAssertEqual(context.confirmationPaymentMethodID, "pm_destination")
        }
    }
}

private final class CancellationTrackingTransaction: STDSTransaction {
    var didCancel = false
    override func cancelChallengeFlow() { didCancel = true }
}

private final class CredentialTestPayment: PKPayment {
    override var token: PKPaymentToken { CredentialTestPaymentToken() }
}

private final class CredentialTestPaymentToken: PKPaymentToken {
    override var paymentData: Data { Data("{}".utf8) }
    override var paymentMethod: PKPaymentMethod { PKPaymentMethod() }
    override var transactionIdentifier: String { "Simulated Identifier" }
}
