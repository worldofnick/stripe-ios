//
//  Checkout+UpdatePaymentMethod.swift
//  StripePaymentSheet
//
//  Created by Nick Porter on 7/24/26.
//  Copyright © 2026 Stripe, Inc. All rights reserved.
//

import Foundation
@_spi(STP) import StripeCore
@_spi(STP) import StripePayments

private enum CheckoutSavedPaymentMethodUpdateError: Error {
    case missingUpdatedPaymentMethod
}

extension Checkout {
    /// Updates a saved payment method, commits the refreshed session, and keeps its billing tax
    /// region in sync when Checkout automatic tax is sourced from billing.
    func updateSavedPaymentMethod(
        _ paymentMethodID: String,
        billingDetails: PaymentMethodBillingDetails?,
        expiryDetails: PaymentMethodExpiryDetails?
    ) async throws -> STPPaymentMethod {
        try await performUpdate(
            .updateSavedPaymentMethod(
                paymentMethodID: paymentMethodID,
                billingDetails: billingDetails,
                expiryDetails: expiryDetails
            ),
            canUpdateWhileSheetPresented: true
        )
        guard let updatedPaymentMethod = session.customer?.paymentMethods.first(where: {
            $0.stripeId == paymentMethodID
        }) else {
            let error = CheckoutSavedPaymentMethodUpdateError.missingUpdatedPaymentMethod
            let errorAnalytic = ErrorAnalytic(
                event: .unexpectedPaymentSheetError,
                error: error,
                additionalNonPIIParams: ["payment_method_id": paymentMethodID]
            )
            STPAnalyticsClient.sharedClient.log(analytic: errorAnalytic)
            stpAssertionFailure(
                "Checkout session response didn't include the updated payment method."
            )
            throw CheckoutError.apiError(
                message: "Checkout session response didn't include the updated payment method."
            )
        }
        try await syncBillingAddress(from: updatedPaymentMethod.billingDetails)
        return updatedPaymentMethod
    }
}
