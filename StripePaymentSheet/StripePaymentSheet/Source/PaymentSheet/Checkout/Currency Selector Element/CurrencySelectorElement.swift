//
//  CurrencySelectorElement.swift
//  StripePaymentSheet
//
//  Created by Nick Porter on 4/8/26.
//

@_spi(STP) import StripeCore

/// An Adaptive Pricing currency selector backed by a Checkout Session.
///
/// Obtain an instance from ``Checkout/getCurrencySelectorElement()`` and use
/// ``view`` in SwiftUI or ``uiView`` in UIKit.
@MainActor
@_spi(STP)
@_spi(ReactNativeSDK)
public final class CurrencySelectorElement {
    // MARK: - Public Properties

    /// A SwiftUI view that displays the currency selector.
    public let view: CurrencySelectorElementView

    /// A UIKit view that displays the currency selector.
    public let uiView: CurrencySelectorElementUIView

    // MARK: - Private Properties

    private let viewModel: CurrencySelectorElementViewModel
    private var hasLoggedInitialization = false

    // MARK: - Internal Methods

    init(checkout: Checkout) async {
        let flagImageManager = AdaptivePricingFlagImageManager()
        await flagImageManager.prefetchFlagImages(for: checkout.session)

        let uiView = CurrencySelectorElementUIView(
            checkout: checkout,
            appearance: checkout.configuration.currencySelectorElement.appearance,
            flagImageManager: flagImageManager
        )
        let viewModel = CurrencySelectorElementViewModel(
            uiView: uiView,
            isAvailable: CurrencySelectorUtilities.adaptivePricingData(from: checkout.session) != nil
        )

        self.uiView = uiView
        self.viewModel = viewModel
        self.view = CurrencySelectorElementView(viewModel: viewModel)
    }

    func update(session: Checkout.Session) {
        uiView.update(session: session)
        viewModel.isAvailable = CurrencySelectorUtilities.adaptivePricingData(from: session) != nil
    }

    func logInitializationIfNeeded() {
        guard !hasLoggedInitialization else { return }
        hasLoggedInitialization = true
        STPAnalyticsClient.sharedClient.log(
            analytic: PaymentSheetAnalytic(
                event: .adaptivePricingCurrencySelectorInit,
                additionalParams: ["is_standalone_element": true]
            )
        )
    }
}
