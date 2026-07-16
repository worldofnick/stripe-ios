//
//  PaymentSheetSelectionSnapshot.swift
//  StripePaymentSheet
//

import Foundation
@_spi(STP) import StripePayments

/// A snapshot of the customer's payment method selection, captured when a sheet is presented so that
/// cancelling the sheet can revert both the in-memory selection and the locally persisted default
/// back to their at-presentation values.
struct SelectionSnapshot {
    /// The in-memory selection at presentation time.
    let paymentOption: PaymentOption?
    /// The locally persisted default (`UserDefaults`) at presentation time.
    let localCustomerPaymentOption: CustomerPaymentOption?
    /// The ids of the saved payment methods displayed by the sheet at presentation time. Used to
    /// distinguish a payment method deleted during the presentation (visible then, gone at cancel)
    /// from one that still exists but is filtered out of this sheet's display (e.g. by intent
    /// payment method types or configuration).
    let savedPaymentMethodIDsAtPresentation: Set<String>

    /// Captures the current selection state for the given customer.
    static func capture(paymentOption: PaymentOption?, customerID: String?, savedPaymentMethods: [STPPaymentMethod]) -> SelectionSnapshot {
        return SelectionSnapshot(
            paymentOption: paymentOption,
            localCustomerPaymentOption: CustomerPaymentOption.localDefaultPaymentMethod(for: customerID),
            savedPaymentMethodIDsAtPresentation: Set(savedPaymentMethods.map(\.stripeId))
        )
    }

    /// Returns a copy of this snapshot with the Link selection cleared. Used when the user drops out
    /// of the native Link flow, which deliberately deselects Link — cancelling afterwards must not
    /// resurrect Link, in memory or in the persisted default.
    var clearingLinkSelection: SelectionSnapshot {
        return SelectionSnapshot(
            paymentOption: nil,
            localCustomerPaymentOption: localCustomerPaymentOption == .link ? nil : localCustomerPaymentOption,
            savedPaymentMethodIDsAtPresentation: savedPaymentMethodIDsAtPresentation
        )
    }

    /// Whether the snapshotted payment option can still be reverted to. False only if it referenced a
    /// saved payment method that no longer exists (e.g. the user deleted it while the sheet was
    /// presented) — in which case the sheet's own post-deletion selection should be kept instead.
    /// Other cases identify a payment method type, not a saved instance, and the available types can't
    /// change while the sheet is presented.
    func isPaymentOptionValid(savedPaymentMethods: [STPPaymentMethod]) -> Bool {
        guard case .saved(let paymentMethod, let confirmParams) = paymentOption else {
            return true
        }
        if confirmParams?.instantDebitsLinkedBank != nil {
            // Not a customer-saved payment method: Instant Debits / Link Card Brand forms create
            // their payment method during bank auth and return it as `.saved`, so it never appears
            // in `savedPaymentMethods` and deletions can't invalidate it.
            return true
        }
        return savedPaymentMethods.contains(where: { $0.stripeId == paymentMethod.stripeId })
    }

    /// Restores the locally persisted default to its at-presentation value, unless it referenced a saved
    /// payment method that no longer exists, in which case it's cleared. Only local `UserDefaults` state
    /// is touched — the server-side default is never reverted.
    func restoreLocalPersistence(customerID: String?, savedPaymentMethods: [STPPaymentMethod]) {
        var valueToRestore = localCustomerPaymentOption
        if case .stripeId(let stripeId) = localCustomerPaymentOption,
           savedPaymentMethodIDsAtPresentation.contains(stripeId),
           !savedPaymentMethods.contains(where: { $0.stripeId == stripeId }) {
            // The persisted PM was visible at presentation but is gone now — it was deleted while
            // the sheet was presented; don't restore a dead reference. (A PM that was never visible
            // isn't deleted — it's merely filtered out of this sheet — and is restored normally.)
            valueToRestore = nil
        }
        guard valueToRestore != CustomerPaymentOption.localDefaultPaymentMethod(for: customerID) else {
            return
        }
        CustomerPaymentOption.setDefaultPaymentMethod(valueToRestore, forCustomer: customerID)
    }
}
