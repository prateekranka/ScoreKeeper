import Foundation
import Observation
import StoreKit

@MainActor
protocol StoreProductLoading {
    func product(withID productID: String) async throws -> Product?
}

@MainActor
struct LiveStoreProductLoader: StoreProductLoading {
    func product(withID productID: String) async throws -> Product? {
        try await Product.products(for: [productID]).first
    }
}

@MainActor
@Observable
final class StoreManager {
    // Keep this identifier aligned with the existing App Store Connect product.
    static let productID = "com.icequeen.scorekeeper.unlimited"
    static let freeGameLimit = 25

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case restoring
        case success
        case failed(String)
    }

    enum ProductState: Equatable {
        case notLoaded
        case loading
        case loaded
        case unavailable(String)
    }

    var product: Product?
    var productState: ProductState = .notLoaded
    var purchaseState: PurchaseState = .idle
    var isUnlocked: Bool {
        didSet { defaults.set(isUnlocked, forKey: Keys.proUnlocked) }
    }
    private(set) var gamesStartedCount: Int
    var paywallPresentedThisSession = false

    var displayPrice: String {
        product?.displayPrice ?? "Price unavailable"
    }

    var canPurchase: Bool {
        guard product != nil else { return false }
        guard case .loaded = productState else { return false }
        switch purchaseState {
        case .loading, .purchasing, .restoring:
            return false
        case .idle, .success, .failed:
            return true
        }
    }

    var remainingFreeGames: Int {
        max(0, Self.freeGameLimit - gamesStartedCount)
    }

    var canStartNewGame: Bool {
        isUnlocked || remainingFreeGames > 0
    }

    var shouldShowFreeGamesSignal: Bool {
        !isUnlocked && gamesStartedCount >= Self.freeGameLimit - 3
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let allowanceStorage: any GameAllowanceStorage
    @ObservationIgnored private let productLoader: any StoreProductLoading
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        allowanceStorage: (any GameAllowanceStorage)? = nil,
        productLoader: (any StoreProductLoading)? = nil,
        startStoreKitTasks: Bool = true
    ) {
        self.defaults = defaults
        self.isUnlocked = defaults.bool(forKey: Keys.proUnlocked)
        let isInMemoryStore = ProcessInfo.processInfo.arguments.contains("-in-memory-store")
        let resolvedAllowanceStorage = allowanceStorage
            ?? (isInMemoryStore ? InMemoryGameAllowanceStorage() : KeychainGameAllowanceStorage())
        self.allowanceStorage = resolvedAllowanceStorage
        self.productLoader = productLoader ?? LiveStoreProductLoader()

        if isInMemoryStore && allowanceStorage == nil {
            // UI tests must never read/write the user's persistent Keychain or
            // carry a prior device allowance into an in-memory launch.
            self.gamesStartedCount = 0
            resolvedAllowanceStorage.writeCount(0)
            defaults.set(0, forKey: Keys.gamesStartedCount)
        } else {
            self.gamesStartedCount = GameAllowanceMigration.migrate(
                defaults: defaults,
                storage: resolvedAllowanceStorage,
                defaultsKey: Keys.gamesStartedCount
            )
        }

        applyLaunchArguments()

        guard startStoreKitTasks else { return }

        if !isInMemoryStore {
            transactionUpdatesTask = Task { [weak self] in
                await self?.listenForTransactionUpdates()
            }
        }

        Task { [weak self] in
            await self?.loadProduct()
            if !isInMemoryStore {
                await self?.refreshEntitlements()
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProduct(forceRetry: Bool = false) async {
        guard product == nil, productState != .loading || forceRetry else { return }

        product = nil
        productState = .loading
        purchaseState = .loading
        do {
            guard let loadedProduct = try await productLoader.product(withID: Self.productID) else {
                productState = .unavailable("PipCount Pro is unavailable right now.")
                purchaseState = .failed("The unlock is unavailable right now.")
                return
            }

            product = loadedProduct
            productState = .loaded
            purchaseState = .idle
        } catch {
            productState = .unavailable("Unable to load PipCount Pro right now.")
            purchaseState = .failed("Unable to load the unlock right now.")
        }
    }

    func retryProductLoad() async {
        await loadProduct(forceRetry: true)
    }

    @discardableResult
    func purchase() async -> Bool {
        if product == nil {
            await loadProduct()
        }

        guard let product else {
            purchaseState = .failed("The unlock is not available right now.")
            return false
        }

        guard case .loaded = productState else {
            purchaseState = .failed("The unlock is not available right now.")
            return false
        }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    purchaseState = .failed("The purchase could not be verified.")
                    return false
                }

                isUnlocked = true
                purchaseState = .success
                await transaction.finish()
                return true
            case .pending:
                purchaseState = .failed("The purchase is pending approval.")
                return false
            case .userCancelled:
                purchaseState = .idle
                return false
            @unknown default:
                purchaseState = .failed("The purchase could not be completed.")
                return false
            }
        } catch {
            purchaseState = Self.purchaseState(for: error)
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        purchaseState = .restoring

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if isUnlocked {
                purchaseState = .success
                return true
            } else {
                purchaseState = .failed("No PipCount Pro purchase was found.")
                return false
            }
        } catch {
            purchaseState = .failed("Restore could not be completed.")
            return false
        }
    }

    func refreshEntitlements() async {
        var hasActiveEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result),
                  transaction.productID == Self.productID else {
                continue
            }

            if transaction.revocationDate == nil {
                hasActiveEntitlement = true
            }
        }

        applyEntitlementSnapshot(hasActiveEntitlement: hasActiveEntitlement)
    }

    // StoreKit's verified entitlement cache is the source of truth, including
    // when a refund or revocation removes a previously cached unlock.
    func applyEntitlementSnapshot(hasActiveEntitlement: Bool) {
        isUnlocked = hasActiveEntitlement
    }

    static func purchaseState(for error: Error) -> PurchaseState {
        if case StoreKitError.userCancelled = error {
            return .idle
        }
        return .failed("The purchase could not be completed.")
    }

    func recordGameStarted() {
        let persistedCount = max(0, allowanceStorage.readCount() ?? 0)
        setGamesStartedCount(max(gamesStartedCount, persistedCount) + 1)
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = verifiedTransaction(from: result),
                  transaction.productID == Self.productID else {
                continue
            }

            isUnlocked = transaction.revocationDate == nil
            await transaction.finish()
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }

    private func applyLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-in-memory-store") else { return }

        isUnlocked = false
        setGamesStartedCount(0)

        if arguments.contains("-free-games-exhausted") {
            setGamesStartedCount(Self.freeGameLimit)
        }

        if arguments.contains("-unlock-pro") {
            isUnlocked = true
        }

    }

    private func setGamesStartedCount(_ proposedCount: Int) {
        let currentCount = max(0, gamesStartedCount)
        let storedCount = max(0, allowanceStorage.readCount() ?? 0)
        let nextCount = max(max(currentCount, storedCount), proposedCount)

        gamesStartedCount = nextCount
        allowanceStorage.writeCount(nextCount)
        // Keep the legacy mirror for compatibility with older app builds.
        defaults.set(nextCount, forKey: Keys.gamesStartedCount)
    }
}

private enum Keys {
    static let proUnlocked = "proUnlocked"
    static let gamesStartedCount = "gamesStartedCount"
}
