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

    /// Captures the current selection state for the given customer.
    static func capture(paymentOption: PaymentOption?, customerID: String?) -> SelectionSnapshot {
        return SelectionSnapshot(
            paymentOption: paymentOption,
            localCustomerPaymentOption: CustomerPaymentOption.localDefaultPaymentMethod(for: customerID)
        )
    }

    /// Returns a copy of this snapshot with the in-memory payment option cleared, preserving the
    /// persisted value. Used when the snapshotted selection is intentionally cleared while the sheet
    /// is presented (e.g. the user drops out of the Link flow).
    var clearingPaymentOption: SelectionSnapshot {
        return SelectionSnapshot(paymentOption: nil, localCustomerPaymentOption: localCustomerPaymentOption)
    }

    /// Whether the snapshotted payment option can still be reverted to. False only if it referenced a
    /// saved payment method that no longer exists (e.g. the user deleted it while the sheet was
    /// presented) — in which case the sheet's own post-deletion selection should be kept instead.
    /// Other cases identify a payment method type, not a saved instance, and the available types can't
    /// change while the sheet is presented.
    func isPaymentOptionValid(savedPaymentMethods: [STPPaymentMethod]) -> Bool {
        guard case .saved(let paymentMethod, _) = paymentOption else {
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
           !savedPaymentMethods.contains(where: { $0.stripeId == stripeId }) {
            // The persisted PM was deleted while the sheet was presented; don't restore a dead reference.
            valueToRestore = nil
        }
        guard valueToRestore != CustomerPaymentOption.localDefaultPaymentMethod(for: customerID) else {
            return
        }
        CustomerPaymentOption.setDefaultPaymentMethod(valueToRestore, forCustomer: customerID)
    }
}
