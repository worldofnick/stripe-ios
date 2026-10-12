import Foundation
@_spi(STP) import StripeApplePay
@_spi(STP) import StripeCore
@_spi(STP) import StripePayments

public extension PaymentSheet.IntentConfiguration {
    /// The intent created by your server and the credentials used to finish this confirmation attempt.
    /// This does not change the credentials used to load PaymentSheet or collect payment details.
    struct ConfirmationResult {
        public let clientSecret: String
        public let publishableKey: String?
        public let stripeAccount: String?

        /// Uses the original PaymentSheet API client, including its Stripe account.
        public init(clientSecret: String) {
            self.clientSecret = clientSecret
            self.publishableKey = nil
            self.stripeAccount = nil
        }

        /// Uses these credentials for intent retrieval, confirmation, and authentication, including 3DS.
        /// A nil `stripeAccount` sends no Stripe-Account header; it does not inherit the original account.
        /// Your server must prepare the intent and payment method in the destination account.
        /// Customer objects and confirmation tokens are not transferred between accounts.
        public init(clientSecret: String, publishableKey: String, stripeAccount: String? = nil) {
            self.clientSecret = clientSecret
            self.publishableKey = publishableKey
            self.stripeAccount = stripeAccount
        }

        func makeAPIClient(fallback: STPAPIClient) throws -> STPAPIClient {
            guard let publishableKey else { return fallback }
            guard ["pk_test_", "pk_live_"].contains(where: { publishableKey.hasPrefix($0) && publishableKey.count > $0.count }),
                  !publishableKey.contains(where: { $0.isWhitespace }),
                  stripeAccount.map({ $0.hasPrefix("acct_") && $0.count > 5 && !$0.contains(where: { $0.isWhitespace }) }) ?? true else {
                throw PaymentSheetError.integrationError(nonPIIDebugDescription: "ConfirmationResult requires a valid publishable key and, if supplied, a valid Stripe account ID.")
            }
            let client = fallback.makeCopy()
            client.publishableKey = publishableKey
            client.stripeAccount = stripeAccount
            return client
        }

        func changesCredentials(from client: STPAPIClient) -> Bool {
            guard let publishableKey else { return false }
            return publishableKey != client.publishableKey || stripeAccount != client.stripeAccount
        }

        func validateClientSideConfirmation(confirmType: PaymentSheet.ConfirmPaymentMethodType, originalClient: STPAPIClient) throws {
            guard changesCredentials(from: originalClient) else { return }
            if originalClient.publishableKeyIsUserKey {
                throw PaymentSheetError.integrationError(nonPIIDebugDescription: "Confirm the intent on your server when switching from a Dashboard user key to a publishable key, to preserve MOTO handling.")
            }
            if case .saved(_, _, _, let radarOptions) = confirmType,
               let radarOptions,
               radarOptions.hcaptchaToken != nil || radarOptions.iosVerificationObject != nil || !radarOptions.additionalAPIParameters.isEmpty {
                throw PaymentSheetError.integrationError(nonPIIDebugDescription: "Confirm the intent on your server before changing credentials when the saved payment method has Radar challenge data. Fraud verification is scoped to the original account.")
            }
        }
    }
}

extension PaymentSheet.IntentConfiguration {
    var resolvedPaymentMethodConfirmHandler: ConfirmHandlerWithPaymentMethod? {
        if let confirmHandlerWithPaymentMethod { return confirmHandlerWithPaymentMethod }
        guard let confirmHandler else { return nil }
        return { paymentMethod, shouldSave in
            ConfirmationResult(clientSecret: try await confirmHandler(paymentMethod, shouldSave))
        }
    }

    var resolvedConfirmationTokenConfirmHandler: ConfirmHandlerWithConfirmationToken? {
        if let confirmHandlerWithConfirmationToken { return confirmHandlerWithConfirmationToken }
        guard let confirmationTokenConfirmHandler else { return nil }
        return { token in
            ConfirmationResult(clientSecret: try await confirmationTokenConfirmHandler(token))
        }
    }
}

extension PaymentSheet.IntentConfiguration.ConfirmationResult {
    @MainActor
    func prepareApplePayConfirmation(
        context: STPApplePayContext,
        mode: PaymentSheet.IntentConfiguration.Mode,
        paymentMethod: STPPaymentMethod?
    ) async throws -> String {
        guard clientSecret != PaymentSheet.IntentConfiguration.COMPLETE_WITHOUT_CONFIRMING_INTENT else {
            return STPApplePayContext.COMPLETE_WITHOUT_CONFIRMING_INTENT
        }
        guard publishableKey != nil else { return clientSecret }
        let client = try makeAPIClient(fallback: context.apiClient)
        if changesCredentials(from: context.apiClient) {
            let destinationPaymentMethod: STPPaymentMethod?
            let needsConfirmation: Bool
            switch mode {
            case .payment:
                let intent = try await client.retrievePaymentIntent(clientSecret: clientSecret, expand: ["payment_method"])
                destinationPaymentMethod = intent.paymentMethod
                needsConfirmation = [.requiresPaymentMethod, .requiresConfirmation].contains(intent.status)
            case .setup:
                let intent = try await client.retrieveSetupIntent(clientSecret: clientSecret, expand: ["payment_method"])
                destinationPaymentMethod = intent.paymentMethod
                needsConfirmation = [.requiresPaymentMethod, .requiresConfirmation, .requiresAction].contains(intent.status)
            }
            if let paymentMethod {
                try PaymentSheetDeferredValidator.validatePaymentMethod(intentPaymentMethod: destinationPaymentMethod, paymentMethod: paymentMethod)
            }
            if needsConfirmation {
                guard paymentMethod != nil, let destinationPaymentMethod else {
                    throw PaymentSheetError.integrationError(nonPIIDebugDescription: "Attach the selected payment method to the destination intent, or confirm it on your server, before returning Apple Pay confirmation credentials.")
                }
                context.confirmationPaymentMethodID = destinationPaymentMethod.stripeId
            }
        }
        context.confirmationAPIClient = client
        return clientSecret
    }
}
