import StoreKit
import XCTest
@testable import ScoreKeeper

@MainActor
final class StoreManagerStoreKitTests: XCTestCase {
    func testLocalCatalogMatchesNonConsumableProProduct() throws {
        let configurationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ScoreKeeper/ScoreKeeper.storekit")
        let data = try Data(contentsOf: configurationURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let products = try XCTUnwrap(catalog["products"] as? [[String: Any]])
        let proProduct = try XCTUnwrap(products.first)

        XCTAssertEqual(proProduct["productID"] as? String, StoreManager.productID)
        XCTAssertEqual(proProduct["type"] as? String, "NonConsumable")
    }

    func testMissingCurrentEntitlementRevokesStaleCachedUnlock() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "proUnlocked")
        let manager = makeManager(defaults: defaults)

        manager.applyEntitlementSnapshot(hasActiveEntitlement: false)

        XCTAssertFalse(manager.isUnlocked)
        XCTAssertFalse(defaults.bool(forKey: "proUnlocked"))
    }

    func testActiveCurrentEntitlementPersistsUnlock() {
        let defaults = makeDefaults()
        let manager = makeManager(defaults: defaults)

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

    func testEmptyProductResponseIsUnavailableAndRetryIsDeterministic() async {
        // A real App Store / sandbox outage cannot be made deterministic in a
        // unit test, so this loader seam covers the same unavailable/retry path.
        let loader = StubStoreProductLoader(responses: [.success(nil), .success(nil)])
        let manager = makeManager(productLoader: loader)

        await manager.loadProduct()

        XCTAssertEqual(
            manager.productState,
            .unavailable("PipCount Pro is unavailable right now.")
        )
        XCTAssertNil(manager.product)
        XCTAssertEqual(manager.displayPrice, "Price unavailable")
        XCTAssertFalse(manager.canPurchase)
        XCTAssertEqual(loader.requestCount, 1)

        await manager.retryProductLoad()

        XCTAssertEqual(loader.requestCount, 2)
        XCTAssertEqual(
            manager.productState,
            .unavailable("PipCount Pro is unavailable right now.")
        )
        XCTAssertFalse(manager.canPurchase)
    }

    func testProductLookupErrorIsUnavailableAndDoesNotEnablePurchase() async {
        let loader = StubStoreProductLoader(responses: [.failure(TestError.productUnavailable)])
        let manager = makeManager(productLoader: loader)

        await manager.loadProduct()

        XCTAssertEqual(
            manager.productState,
            .unavailable("Unable to load PipCount Pro right now.")
        )
        XCTAssertFalse(manager.canPurchase)
        XCTAssertNotEqual(manager.displayPrice, "$0.99")
    }

    func testMigrationUsesMaximumOfKeychainAndLegacyDefaults() {
        let defaults = makeDefaults()
        defaults.set(7, forKey: "gamesStartedCount")
        let storage = InMemoryGameAllowanceStorage(count: 12)

        let migrated = GameAllowanceMigration.migrate(defaults: defaults, storage: storage)

        XCTAssertEqual(migrated, 12)
        XCTAssertEqual(storage.readCount(), 12)
        XCTAssertEqual(defaults.integer(forKey: "gamesStartedCount"), 12)

        // Running the migration again is idempotent and cannot lower the count.
        defaults.set(3, forKey: "gamesStartedCount")
        XCTAssertEqual(GameAllowanceMigration.migrate(defaults: defaults, storage: storage), 12)
        XCTAssertEqual(defaults.integer(forKey: "gamesStartedCount"), 12)
    }

    func testRecordGameStartedNeverDecrementsAllowance() {
        let defaults = makeDefaults()
        defaults.set(4, forKey: "gamesStartedCount")
        let storage = InMemoryGameAllowanceStorage(count: 10)
        let manager = makeManager(defaults: defaults, allowanceStorage: storage)

        XCTAssertEqual(manager.gamesStartedCount, 10)
        defaults.set(1, forKey: "gamesStartedCount")
        manager.recordGameStarted()

        XCTAssertEqual(manager.gamesStartedCount, 11)
        XCTAssertEqual(storage.readCount(), 11)
        XCTAssertEqual(defaults.integer(forKey: "gamesStartedCount"), 11)
    }

    func testRevocationSnapshotRemovesPreviouslyCachedUnlock() {
        let manager = makeManager()
        manager.applyEntitlementSnapshot(hasActiveEntitlement: true)
        XCTAssertTrue(manager.isUnlocked)

        manager.applyEntitlementSnapshot(hasActiveEntitlement: false)

        XCTAssertFalse(manager.isUnlocked)
    }

    func testFreeAllowanceBoundaries() {
        for (count, remaining, canStart) in [(0, 25, true), (24, 1, true), (25, 0, false), (26, 0, false)] {
            let manager = makeManager(
                defaults: makeDefaults(),
                allowanceStorage: InMemoryGameAllowanceStorage(count: count)
            )

            XCTAssertEqual(manager.gamesStartedCount, count)
            XCTAssertEqual(manager.remainingFreeGames, remaining)
            XCTAssertEqual(manager.canStartNewGame, canStart)
        }
    }

    func testUnlockedBypassesFreeAllowanceAtAndAboveLimit() {
        let manager = makeManager(
            defaults: makeDefaults(),
            allowanceStorage: InMemoryGameAllowanceStorage(count: 26)
        )
        manager.applyEntitlementSnapshot(hasActiveEntitlement: true)

        XCTAssertTrue(manager.isUnlocked)
        XCTAssertTrue(manager.canStartNewGame)
    }

    func testRecordGameStartedCrossesFreeAllowanceBoundary() {
        let storage = InMemoryGameAllowanceStorage(count: 24)
        let manager = makeManager(defaults: makeDefaults(), allowanceStorage: storage)

        manager.recordGameStarted()
        XCTAssertEqual(manager.gamesStartedCount, 25)
        XCTAssertFalse(manager.canStartNewGame)
        XCTAssertEqual(storage.readCount(), 25)

        manager.recordGameStarted()
        XCTAssertEqual(manager.gamesStartedCount, 26)
        XCTAssertEqual(storage.readCount(), 26)
    }

    func testReviewAskEligibleCountsRequestOnSecondSession() {
        for count in [2, 5] {
            let defaults = makeDefaults()
            _ = makeReviewManager(defaults: defaults)
            let manager = makeReviewManager(defaults: defaults)

            manager.considerReviewAsk(completedGameCount: count, paywallPresentedThisSession: false, now: Date(timeIntervalSince1970: 1_000))

            XCTAssertTrue(manager.reviewRequestPending, "count \(count) should be eligible")
        }
    }

    func testReviewAskSuppressesNonEligibleCounts() {
        for count in [0, 1, 3, 4, 6] {
            let defaults = makeDefaults()
            _ = makeReviewManager(defaults: defaults)
            let manager = makeReviewManager(defaults: defaults)

            manager.considerReviewAsk(completedGameCount: count, paywallPresentedThisSession: false, now: Date(timeIntervalSince1970: 1_000))

            XCTAssertFalse(manager.reviewRequestPending, "count \(count) should not be eligible")
        }
    }

    func testReviewAskSuppressesFirstSessionAndPaywall() {
        let firstSession = makeReviewManager(defaults: makeDefaults())
        firstSession.considerReviewAsk(completedGameCount: 2, paywallPresentedThisSession: false, now: Date(timeIntervalSince1970: 1_000))
        XCTAssertFalse(firstSession.reviewRequestPending)

        let defaults = makeDefaults()
        _ = makeReviewManager(defaults: defaults)
        let secondSession = makeReviewManager(defaults: defaults)
        secondSession.considerReviewAsk(completedGameCount: 2, paywallPresentedThisSession: true, now: Date(timeIntervalSince1970: 1_000))
        XCTAssertFalse(secondSession.reviewRequestPending)
    }

    func testReviewAskThrottleSuppressesBeforeBoundaryButAllowsAtBoundary() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let throttleSeconds = 120 * 24 * 60 * 60
        let defaults = makeDefaults()
        _ = makeReviewManager(defaults: defaults)
        defaults.set(now.addingTimeInterval(-Double(throttleSeconds) + 1), forKey: "lastReviewAskDate")
        let beforeBoundary = makeReviewManager(defaults: defaults)
        beforeBoundary.considerReviewAsk(completedGameCount: 2, paywallPresentedThisSession: false, now: now)
        XCTAssertFalse(beforeBoundary.reviewRequestPending)

        defaults.set(now.addingTimeInterval(-Double(throttleSeconds)), forKey: "lastReviewAskDate")
        let atBoundary = makeReviewManager(defaults: defaults)
        atBoundary.considerReviewAsk(completedGameCount: 2, paywallPresentedThisSession: false, now: now)
        XCTAssertTrue(atBoundary.reviewRequestPending)
    }

    func testReviewAskSuppressesDuplicatePendingRequestAndConsumeClearsIt() {
        let defaults = makeDefaults()
        _ = makeReviewManager(defaults: defaults)
        let manager = makeReviewManager(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_000)

        manager.considerReviewAsk(completedGameCount: 2, paywallPresentedThisSession: false, now: now)
        manager.considerReviewAsk(completedGameCount: 5, paywallPresentedThisSession: false, now: now)
        XCTAssertTrue(manager.reviewRequestPending)

        manager.consumeReviewRequest()
        XCTAssertFalse(manager.reviewRequestPending)
        manager.consumeReviewRequest()
        XCTAssertFalse(manager.reviewRequestPending)
    }

    func testReviewAskUsesIsolatedDefaultsAcrossSuites() {
        let firstDefaults = makeDefaults()
        _ = makeReviewManager(defaults: firstDefaults)
        let firstManager = makeReviewManager(defaults: firstDefaults)
        firstManager.considerReviewAsk(completedGameCount: 2, paywallPresentedThisSession: false, now: Date(timeIntervalSince1970: 1_000))
        XCTAssertTrue(firstManager.reviewRequestPending)

        let secondManager = makeReviewManager(defaults: makeDefaults())
        secondManager.considerReviewAsk(completedGameCount: 2, paywallPresentedThisSession: false, now: Date(timeIntervalSince1970: 1_000))
        XCTAssertFalse(secondManager.reviewRequestPending)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "StoreManagerStoreKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeManager(
        defaults: UserDefaults? = nil,
        allowanceStorage: (any GameAllowanceStorage)? = nil,
        productLoader: (any StoreProductLoading)? = nil
    ) -> StoreManager {
        StoreManager(
            defaults: defaults ?? makeDefaults(),
            allowanceStorage: allowanceStorage ?? InMemoryGameAllowanceStorage(),
            productLoader: productLoader,
            startStoreKitTasks: false
        )
    }

    private func makeReviewManager(defaults: UserDefaults) -> ReviewAskManager {
        ReviewAskManager(defaults: defaults)
    }
}

@MainActor
private final class StubStoreProductLoader: StoreProductLoading {
    private var responses: [Result<Product?, Error>]
    private(set) var requestCount = 0

    init(responses: [Result<Product?, Error>]) {
        self.responses = responses
    }

    func product(withID productID: String) async throws -> Product? {
        requestCount += 1
        guard !responses.isEmpty else { return nil }
        return try responses.removeFirst().get()
    }
}

private enum TestError: Error {
    case productUnavailable
}
