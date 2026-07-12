import Foundation
import Observation
import StoreKit

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

    var product: Product?
    var purchaseState: PurchaseState = .idle
    var isUnlocked: Bool {
        didSet { defaults.set(isUnlocked, forKey: Keys.proUnlocked) }
    }
    var gamesStartedCount: Int {
        didSet { defaults.set(gamesStartedCount, forKey: Keys.gamesStartedCount) }
    }
    var paywallPresentedThisSession = false

    var displayPrice: String {
        product?.displayPrice ?? "$0.99"
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
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isUnlocked = defaults.bool(forKey: Keys.proUnlocked)
        self.gamesStartedCount = max(0, defaults.integer(forKey: Keys.gamesStartedCount))

        applyLaunchArguments()

        transactionUpdatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }

        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProduct() async {
        guard product == nil else { return }

        purchaseState = .loading
        do {
            product = try await Product.products(for: [Self.productID]).first
            purchaseState = .idle
        } catch {
            purchaseState = .failed("Unable to load the unlock right now.")
        }
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
                purchaseState = .failed("No ScoreKeeper Pro purchase was found.")
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
        gamesStartedCount = max(gamesStartedCount, defaults.integer(forKey: Keys.gamesStartedCount)) + 1
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
        gamesStartedCount = 0

        if arguments.contains("-free-games-exhausted") {
            gamesStartedCount = Self.freeGameLimit
        }

        if arguments.contains("-unlock-pro") {
            isUnlocked = true
        }

    }
}

private enum Keys {
    static let proUnlocked = "proUnlocked"
    static let gamesStartedCount = "gamesStartedCount"
}
