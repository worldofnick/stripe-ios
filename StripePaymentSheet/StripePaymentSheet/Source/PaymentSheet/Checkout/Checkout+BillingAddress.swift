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
    /// Syncs the payment method's billing address to Checkout tax calculation when needed.
    func syncBillingAddress(from billingDetails: STPPaymentMethodBillingDetails?) async throws {
        // Billing details are optional on payment methods. A country is the minimum information
        // Checkout needs to calculate tax, so there is nothing to sync without one.
        guard session.collectsTaxFromBillingAddress,
              let source = billingDetails?.address,
              let country = source.country?.nonEmpty else {
            return
        }
        try await updateBillingTaxRegionIfNecessary(
            address: Address(
                country: country,
                line1: source.line1?.nonEmpty,
                line2: source.line2?.nonEmpty,
                city: source.city?.nonEmpty,
                state: source.state?.nonEmpty,
                postalCode: source.postalCode?.nonEmpty
            ),
            canUpdateWhileSheetPresented: true
        )
    }
}
