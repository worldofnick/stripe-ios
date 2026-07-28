//
//  Checkout+BillingAddress.swift
//  StripePaymentSheet
//
//  Created by Nick Porter on 7/7/26.
//

import Foundation
@_spi(STP) import StripeCore
@_spi(STP) import StripePayments

extension Checkout {
    /// Whether `syncBillingAddress(from:)` will perform an update.
    ///
    /// Callers can use this to avoid presenting loading UI when billing sync is a no-op.
    func willSyncBillingAddress(from billingDetails: STPPaymentMethodBillingDetails?) -> Bool {
        return session.collectsTaxFromBillingAddress
            && billingDetails?.address?.country?.nonEmpty != nil
    }

    /// Syncs the payment method's billing address to Checkout tax calculation when needed.
    func syncBillingAddress(from billingDetails: STPPaymentMethodBillingDetails?) async throws {
        // Billing details are optional on payment methods. A country is the minimum information
        // Checkout needs to calculate tax, so there is nothing to sync without one.
        guard session.collectsTaxFromBillingAddress,
              let country = billingDetails?.address?.country?.nonEmpty else {
            return
        }
        let source = billingDetails?.address
        let address = Address(
            country: country,
            line1: source?.line1?.nonEmpty,
            line2: source?.line2?.nonEmpty,
            city: source?.city?.nonEmpty,
            state: source?.state?.nonEmpty,
            postalCode: source?.postalCode?.nonEmpty
        )
        try await updateBillingTaxRegionIfNecessary(
            address: address,
            canUpdateWhileSheetPresented: true
        )
    }
}
