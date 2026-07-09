import Foundation
import Security
import StoreKit

@MainActor
@Observable
final class StoreAccessManager {
    static let unlimitedGamesProductID = "com.icequeen.scorekeeper.unlimited"
    static let freeGameLimit = 25

    private enum Keys {
        static let gamesStartedCount = "storeAccess.gamesStartedCount"
    }

    private let defaults: UserDefaults
    private let arguments: [String]
    private var updatesTask: Task<Void, Never>?
    private var hasPrepared = false

    private(set) var product: Product?
    private(set) var gamesStartedCount: Int
    private(set) var hasUnlimitedAccess = false
    private(set) var isLoadingProduct = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    var message: String?

    init(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.defaults = defaults
        self.arguments = arguments

        if arguments.contains("-in-memory-store") {
            gamesStartedCount = Self.integerArgument(named: "-free-games-used", in: arguments) ?? 0
        } else {
            gamesStartedCount = max(
                defaults.integer(forKey: Keys.gamesStartedCount),
                DurableGameAllowance.load() ?? 0
            )
            DurableGameAllowance.save(gamesStartedCount)
        }

#if DEBUG
        if arguments.contains("-unlimited-games-unlocked") {
            hasUnlimitedAccess = true
        }
#endif
    }

    var canStartNewGame: Bool {
        hasUnlimitedAccess || gamesStartedCount < Self.freeGameLimit
    }

    var remainingFreeGames: Int {
        max(0, Self.freeGameLimit - gamesStartedCount)
    }

    var displayPrice: String? {
        if let product {
            return product.displayPrice
        }

#if DEBUG
        if arguments.contains("-ui-test-storekit") || arguments.contains("-ui-test-storekit-pending") {
            return "$0.99"
        }
#endif

        return nil
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true
        listenForTransactions()
        await refreshEntitlements()
        await loadProduct()
    }

    func reconcile(existingSessionCount: Int) {
        guard !arguments.contains("-in-memory-store") else { return }
        guard existingSessionCount > gamesStartedCount else { return }
        gamesStartedCount = existingSessionCount
        persistGamesStartedCount()
    }

    func recordGameStarted() {
        gamesStartedCount += 1
        persistGamesStartedCount()
    }

    @discardableResult
    func purchaseUnlimitedGames() async -> Bool {
#if DEBUG
        if arguments.contains("-ui-test-storekit") {
            hasUnlimitedAccess = true
            message = nil
            return true
        }
        if arguments.contains("-ui-test-storekit-pending") {
            message = "Your purchase is pending approval. Unlimited games will unlock automatically when it completes."
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                self?.hasUnlimitedAccess = true
            }
            return false
        }
#endif

        guard let product else {
            message = "The purchase is not available right now. Check your connection and try again."
            return false
        }

        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                guard transaction.productID == Self.unlimitedGamesProductID else {
                    message = "The App Store returned an unexpected purchase."
                    return false
                }

                hasUnlimitedAccess = true
                await transaction.finish()
                return true
            case .pending:
                message = "Your purchase is pending approval. Unlimited games will unlock automatically when it completes."
                return false
            case .userCancelled:
                return false
            @unknown default:
                message = "The purchase could not be completed. Please try again."
                return false
            }
        } catch {
            message = "The purchase could not be verified. Please try again."
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        isRestoring = true
        message = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !hasUnlimitedAccess {
                message = "No previous unlimited-games purchase was found for this Apple Account."
            }
            return hasUnlimitedAccess
        } catch {
            message = "Purchases could not be restored. Please try again."
            return false
        }
    }

    func retryLoadingProduct() async {
        await loadProduct()
    }

    private func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            let loadedProduct = try await Product.products(for: [Self.unlimitedGamesProductID]).first
            if let loadedProduct, loadedProduct.type == .nonConsumable {
                product = loadedProduct
                message = nil
            } else {
                product = nil
                message = "Unlimited games are not available from the App Store yet."
            }
        } catch {
            product = nil
            message = "The App Store could not be reached. Check your connection and try again."
        }
    }

    private func refreshEntitlements() async {
#if DEBUG
        if arguments.contains("-unlimited-games-unlocked") {
            hasUnlimitedAccess = true
            return
        }
#endif

        var isEntitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }
            if transaction.productID == Self.unlimitedGamesProductID {
                isEntitled = true
            }
        }
        hasUnlimitedAccess = isEntitled
    }

    private func listenForTransactions() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.verified(result) else { continue }
                guard transaction.productID == Self.unlimitedGamesProductID else { continue }

                await self.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreAccessError.failedVerification
        }
    }

    private func persistGamesStartedCount() {
        guard !arguments.contains("-in-memory-store") else { return }
        defaults.set(gamesStartedCount, forKey: Keys.gamesStartedCount)
        DurableGameAllowance.save(gamesStartedCount)
    }

    private static func integerArgument(named name: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            return nil
        }
        return Int(arguments[index + 1])
    }
}

private enum DurableGameAllowance {
    private static let service = "com.icequeen.scorekeeper.game-allowance"
    private static let account = "games-started-count"

    static func load() -> Int? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              let count = Int(value) else {
            return nil
        }
        return max(0, count)
    }

    static func save(_ count: Int) {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(String(max(0, count)).utf8)
        ]

        let status = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var item = identity
        item.merge(attributes) { _, new in new }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}

private enum StoreAccessError: Error {
    case failedVerification
}
