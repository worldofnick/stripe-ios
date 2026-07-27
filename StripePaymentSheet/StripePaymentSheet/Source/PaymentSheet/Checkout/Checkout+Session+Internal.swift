//
//  Checkout+Session+Internal.swift
//  StripePaymentSheet
//

import Foundation
@_spi(STP) import StripeCore
@_spi(STP) import StripePayments

// MARK: - Computed Properties

extension Checkout.Session {
    var customerId: String? {
        return customer?.id
    }

    var requiresShippingAddress: Bool {
        allowedShippingCountries != nil
    }

    var isPaymentMethodOptionsSetupFutureUsageSet: Bool {
        return !setupFutureUsageForPaymentMethodType.isEmpty
    }

    /// Whether this Checkout Session computes automatic tax from the billing address.
    var collectsTaxFromBillingAddress: Bool {
        return shouldSendTaxRegion(for: "billing")
    }

    /// Whether confirmation follows setup-style semantics.
    ///
    /// Classic Checkout modes remain authoritative. Modeless sessions surface as ``Mode.unknown``,
    /// so they fall back to the always-present top-level payment status.
    var isSetupStyle: Bool {
        switch mode {
        case .setup:
            return true
        case .payment, .subscription:
            return false
        case .unknown:
            return paymentStatus == .noPaymentRequired
        }
    }
}

// MARK: - Methods

extension Checkout.Session {
    /// Returns `true` when the server needs a `tax_region` update for the given address type.
    ///
    /// - Parameter addressType: Either `"billing"` or `"shipping"`.
    func shouldSendTaxRegion(for addressType: String) -> Bool {
        return automaticTaxEnabled && automaticTaxAddressSource == addressType
    }

    /// The amount to display for payment-style sessions.
    ///
    /// This deliberately differs from ``expectedAmountForConfirm()``: display uses the order
    /// total, while confirmation uses the server's current amount due.
    func displayAmount() -> Int? {
        guard !isSetupStyle else { return nil }
        guard let amount = total?.total.minorUnitsAmount else {
            stpAssertionFailure("Missing display amount from a payment-style checkout session")
            return nil
        }
        return amount
    }

    /// The `expected_amount` to send when confirming a payment-style session. The confirm
    /// endpoint does not accept this parameter for setup-style sessions.
    func expectedAmountForConfirm() -> Int? {
        guard !isSetupStyle else { return nil }
        guard let amountDue else {
            stpAssertionFailure("Missing total_summary.due from a payment-style checkout session")
            return nil
        }
        return amountDue
    }

    func merchantWillSavePaymentMethod(_ paymentMethodType: STPPaymentMethodType) -> Bool {
        guard customerId != nil else {
            return false
        }

        if isSetupStyle {
            return true
        }

        guard let setupFutureUsage = setupFutureUsage(for: paymentMethodType) else {
            return false
        }
        return setupFutureUsage != "none"
    }

    func setupFutureUsage(for paymentMethodType: STPPaymentMethodType) -> String? {
        let perPaymentMethodSetupFutureUsage = setupFutureUsageForPaymentMethodType[paymentMethodType.identifier]
        if let perPaymentMethodSetupFutureUsage {
            return perPaymentMethodSetupFutureUsage
        }

        return setupFutureUsage
    }
}

enum SessionFieldUpdate<Value> {
    case keepOldValue
    case newValue(Value?)

    func resolved(currentValue: Value?) -> Value? {
        switch self {
        case .keepOldValue:
            return currentValue
        case .newValue(let newValue):
            return newValue
        }
    }
}

extension Checkout.Session {
    /// Apologetic explanation for this method:
    /// - Situation: Session is immutable, so all mutations must create a new one.
    /// - Complication: Optional fields need three states here: keep the old value, replace with a non-nil value, or explicitly clear to nil.
    /// - Resolution: SessionFieldUpdate keeps that distinction visible at call sites instead of relying on double optionals.
    func makeCopyOverriding(
        shippingAddress: SessionFieldUpdate<Checkout.Session.ShippingAddress> = .keepOldValue,
        paymentOption: SessionFieldUpdate<Checkout.Session.PaymentOptionDisplayData> = .keepOldValue
    ) -> Self {
        return Self(
            id: id,
            businessName: businessName,
            currency: currency,
            currencyOptions: currencyOptions,
            discountAmounts: discountAmounts,
            email: email,
            lineItems: lineItems,
            livemode: livemode,
            minorUnitsAmountDivisor: minorUnitsAmountDivisor,
            paymentOption: paymentOption.resolved(currentValue: self.paymentOption),
            savedPaymentMethods: savedPaymentMethods,
            shipping: shipping,
            shippingAddress: shippingAddress.resolved(currentValue: self.shippingAddress),
            shippingOptions: shippingOptions,
            status: status,
            tax: tax,
            total: total,
            mode: mode,
            paymentStatus: paymentStatus,
            amountDue: amountDue,
            paymentMethodOptions: paymentMethodOptions,
            customer: customer,
            savedPaymentMethodsOfferSave: savedPaymentMethodsOfferSave,
            setupFutureUsage: setupFutureUsage,
            setupFutureUsageForPaymentMethodType: setupFutureUsageForPaymentMethodType,
            allowedShippingCountries: allowedShippingCountries,
            localizedPricesMetas: localizedPricesMetas,
            exchangeRateMeta: exchangeRateMeta,
            adaptivePricingActive: adaptivePricingActive,
            billingAddressCollection: billingAddressCollection,
            automaticTaxEnabled: automaticTaxEnabled,
            automaticTaxAddressSource: automaticTaxAddressSource,
            elementsSession: elementsSession
        )
    }
}
