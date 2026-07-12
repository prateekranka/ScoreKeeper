import StoreKit
import XCTest

@MainActor
final class StoreManagerStoreKitTests: XCTestCase {
    func testMissingCurrentEntitlementRevokesStaleCachedUnlock() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "proUnlocked")
        let manager = StoreManager(defaults: defaults)

        manager.applyEntitlementSnapshot(hasActiveEntitlement: false)

        XCTAssertFalse(manager.isUnlocked)
        XCTAssertFalse(defaults.bool(forKey: "proUnlocked"))
    }

    func testActiveCurrentEntitlementPersistsUnlock() {
        let defaults = makeDefaults()
        let manager = StoreManager(defaults: defaults)

        manager.applyEntitlementSnapshot(hasActiveEntitlement: true)

        XCTAssertTrue(manager.isUnlocked)
        XCTAssertTrue(defaults.bool(forKey: "proUnlocked"))
    }

    func testUserCancelledErrorReturnsIdleState() {
        XCTAssertEqual(
            StoreManager.purchaseState(for: StoreKitError.userCancelled),
            .idle
        )
    }

    func testOtherPurchaseErrorReturnsCustomerSafeFailure() {
        XCTAssertEqual(
            StoreManager.purchaseState(for: StoreKitError.networkError(URLError(.notConnectedToInternet))),
            .failed("The purchase could not be completed.")
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "StoreManagerStoreKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
