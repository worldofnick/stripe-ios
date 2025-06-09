//
//  PaymentSheetFlowControllerPublishedTests.swift
//  StripePaymentSheetTests
//
//  Tests for @Published paymentOption functionality in PaymentSheet.FlowController
//

import Combine
import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
import StripeCoreTestUtils
import XCTest

@_spi(STP) @testable import StripeCore
@_spi(STP) @testable import StripePayments
@_spi(STP) @testable import StripePaymentSheet

class PaymentSheetFlowControllerPublishedTests: XCTestCase {
    var configuration: PaymentSheet.Configuration!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        configuration = PaymentSheet.Configuration()
        configuration.apiClient = STPAPIClient(publishableKey: STPTestingDefaultPublishableKey)
        configuration.customer = .init(id: "cus_123", ephemeralKeySecret: "ek_456")
        configuration.merchantDisplayName = "Example, Inc."
        
        cancellables = Set<AnyCancellable>()
        
        // Clear product usage prior to testing
        STPAnalyticsClient.sharedClient.clearProductUsage()
    }
    
    override func tearDown() {
        cancellables = nil
        configuration = nil
        super.tearDown()
    }
    
    func testPaymentOptionIsPublished() {
        // Test that paymentOption is properly @Published and updates SwiftUI views
        let expectation = self.expectation(description: "paymentOption publisher fires")
        expectation.expectedFulfillmentCount = 2 // Initial nil value + actual value
        
        var receivedValues: [PaymentSheet.FlowController.PaymentOptionDisplayData?] = []
        
        let intentConfig = PaymentSheet.IntentConfiguration(mode: .payment(amount: 1000, currency: "USD")) { _, _, _ in
            // Test doesn't confirm, so this is unused
        }
        
        PaymentSheet.FlowController.create(intentConfiguration: intentConfig, configuration: configuration) { result in
            switch result {
            case .success(let flowController):
                // Subscribe to paymentOption changes
                flowController.$paymentOption
                    .sink { paymentOption in
                        receivedValues.append(paymentOption)
                        expectation.fulfill()
                    }
                    .store(in: &self.cancellables)
                
            case .failure(let error):
                XCTFail("FlowController creation failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10)
        
        // Should receive initial nil value and potentially another value
        XCTAssertTrue(receivedValues.count >= 1)
        // First value should be nil (no payment method selected initially)
        XCTAssertNil(receivedValues.first)
    }
    
    func testPaymentOptionUpdatesOnIntentConfigurationChange() {
        // Test that paymentOption updates when IntentConfiguration is updated
        let initialIntentConfig = PaymentSheet.IntentConfiguration(mode: .payment(amount: 1000, currency: "USD")) { _, _, _ in
            // Test doesn't confirm, so this is unused
        }
        
        let updateExpectation = expectation(description: "Update completes")
        let publisherExpectation = expectation(description: "paymentOption publisher fires on update")
        publisherExpectation.expectedFulfillmentCount = 3 // Initial nil + after creation + after update
        
        var publisherFireCount = 0
        
        PaymentSheet.FlowController.create(intentConfiguration: initialIntentConfig, configuration: configuration) { result in
            switch result {
            case .success(let flowController):
                // Subscribe to paymentOption changes
                flowController.$paymentOption
                    .sink { _ in
                        publisherFireCount += 1
                        publisherExpectation.fulfill()
                    }
                    .store(in: &self.cancellables)
                
                // Update the intent configuration
                var updatedIntentConfig = initialIntentConfig
                updatedIntentConfig.mode = .setup(currency: "USD", setupFutureUsage: .offSession)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    flowController.update(intentConfiguration: updatedIntentConfig) { error in
                        XCTAssertNil(error)
                        updateExpectation.fulfill()
                    }
                }
                
            case .failure(let error):
                XCTFail("FlowController creation failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10)
        
        // Should have fired at least twice: once on creation, once on update
        XCTAssertGreaterThanOrEqual(publisherFireCount, 2)
    }
    
    func testPaymentOptionIsObservableObject() {
        // Test that FlowController conforms to ObservableObject
        let intentConfig = PaymentSheet.IntentConfiguration(mode: .payment(amount: 1000, currency: "USD")) { _, _, _ in
            // Test doesn't confirm, so this is unused
        }
        
        let expectation = self.expectation(description: "FlowController created")
        
        PaymentSheet.FlowController.create(intentConfiguration: intentConfig, configuration: configuration) { result in
            switch result {
            case .success(let flowController):
                // Verify FlowController is ObservableObject
                XCTAssertTrue(flowController is ObservableObject)
                
                // Verify we can access objectWillChange publisher
                let _ = flowController.objectWillChange
                
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("FlowController creation failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10)
    }
    
    func testPaymentOptionUpdatesWhenWalletButtonsViewChanges() {
        // Test that paymentOption updates when walletButtonsShownExternally changes
        let intentConfig = PaymentSheet.IntentConfiguration(mode: .payment(amount: 1000, currency: "USD")) { _, _, _ in
            // Test doesn't confirm, so this is unused
        }
        
        let expectation = self.expectation(description: "FlowController created")
        let publisherExpectation = expectation(description: "paymentOption publisher fires")
        publisherExpectation.expectedFulfillmentCount = 3 // Initial + after creation + after wallet change
        
        var publisherFireCount = 0
        
        PaymentSheet.FlowController.create(intentConfiguration: intentConfig, configuration: configuration) { result in
            switch result {
            case .success(let flowController):
                // Subscribe to paymentOption changes
                flowController.$paymentOption
                    .sink { _ in
                        publisherFireCount += 1
                        publisherExpectation.fulfill()
                    }
                    .store(in: &self.cancellables)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Change wallet buttons state
                    flowController.walletButtonsShownExternally = true
                    expectation.fulfill()
                }
                
            case .failure(let error):
                XCTFail("FlowController creation failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10)
        
        // Should have fired at least twice: once initially, once after wallet change
        XCTAssertGreaterThanOrEqual(publisherFireCount, 2)
    }
    
    func testPaymentOptionUpdatesOnFormClose() {
        // Test that paymentOption updates when form closes (simulating the FlowControllerViewControllerDelegate)
        let intentConfig = PaymentSheet.IntentConfiguration(mode: .payment(amount: 1000, currency: "USD")) { _, _, _ in
            // Test doesn't confirm, so this is unused
        }
        
        let expectation = self.expectation(description: "FlowController created")
        let publisherExpectation = expectation(description: "paymentOption publisher fires")
        publisherExpectation.expectedFulfillmentCount = 3 // Initial + after creation + after form close
        
        var publisherFireCount = 0
        
        PaymentSheet.FlowController.create(intentConfiguration: intentConfig, configuration: configuration) { result in
            switch result {
            case .success(let flowController):
                // Subscribe to paymentOption changes
                flowController.$paymentOption
                    .sink { _ in
                        publisherFireCount += 1
                        publisherExpectation.fulfill()
                    }
                    .store(in: &self.cancellables)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Simulate form closing by calling the delegate method
                    flowController.flowControllerViewControllerShouldClose(flowController.viewController, didCancel: false)
                    expectation.fulfill()
                }
                
            case .failure(let error):
                XCTFail("FlowController creation failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10)
        
        // Should have fired at least twice: once initially, once after form close
        XCTAssertGreaterThanOrEqual(publisherFireCount, 2)
    }
    
    func testPaymentOptionUpdatesOnLinkConfirmOptionChange() {
        // Test that paymentOption updates when linkConfirmOption is set on the view controller
        let intentConfig = PaymentSheet.IntentConfiguration(mode: .payment(amount: 1000, currency: "USD")) { _, _, _ in
            // Test doesn't confirm, so this is unused
        }
        
        let expectation = self.expectation(description: "FlowController created")
        let publisherExpectation = expectation(description: "paymentOption publisher fires")
        publisherExpectation.expectedFulfillmentCount = 3 // Initial + after creation + after link option change
        
        var publisherFireCount = 0
        
        PaymentSheet.FlowController.create(intentConfiguration: intentConfig, configuration: configuration) { result in
            switch result {
            case .success(let flowController):
                // Subscribe to paymentOption changes
                flowController.$paymentOption
                    .sink { _ in
                        publisherFireCount += 1
                        publisherExpectation.fulfill()
                    }
                    .store(in: &self.cancellables)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Simulate setting a link confirm option directly on the view controller
                    flowController.viewController.linkConfirmOption = .wallet
                    flowController.updatePaymentOption()
                    expectation.fulfill()
                }
                
            case .failure(let error):
                XCTFail("FlowController creation failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10)
        
        // Should have fired at least twice: once initially, once after link option change
        XCTAssertGreaterThanOrEqual(publisherFireCount, 2)
    }
} 