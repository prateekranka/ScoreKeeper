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
    static let freeGameLimit = GameAccessPolicy.freeGameLimit

    enum PurchaseState: Equatable {
        case idle, loading, purchasing, restoring, success
        case failed(String)
    }

    enum ProductState: Equatable {
        case notLoaded, loading, loaded
        case unavailable(String)
    }

    private(set) var products: [ProProduct: Product] = [:]
    private(set) var trialEligibleProducts: Set<ProProduct> = []
    private(set) var productState: ProductState = .notLoaded
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var entitlement: ProEntitlement
    private(set) var gamesStartedCount: Int
    private(set) var paywallRoute: PaywallRoute?
    private(set) var hasPreparedLaunch = false
    var paywallPresentedThisSession = false

    var isPro: Bool { currentEntitlement.isPro }
    var hasConverted: Bool { currentEntitlement.hasConverted }
    private var currentEntitlement: ProEntitlement {
        var snapshot = entitlement
        snapshot.evaluatedAt = Date()
        return snapshot
    }
    var isGrandfathered: Bool {
        preferences.value(.accessPolicy) == 2 || (preferences.value(.accessPolicy) == 0 && gamesStartedCount > 0)
    }
    var accessPolicy: GameAccessPolicy {
        GameAccessPolicy(isGrandfathered: isGrandfathered, gamesStartedCount: gamesStartedCount)
    }
    var remainingFreeGames: Int { accessPolicy.remainingFreeGames }
    var canStartNewGame: Bool { accessPolicy.canStartNewGame(isPro: isPro) }
    var shouldShowFreeGamesSignal: Bool { accessPolicy.showsRemainingCount(isPro: isPro) }
    var isBusy: Bool { purchaseState == .purchasing || purchaseState == .restoring }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let allowanceStorage: any GameAllowanceStorage
    @ObservationIgnored private let productLoader: any StoreProductLoading
    @ObservationIgnored let preferences: MonetizationPreferences
    @ObservationIgnored let notificationScheduler: NotificationScheduler
    @ObservationIgnored private let isInMemoryStore: Bool
    @ObservationIgnored private let launchArguments: [String]
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var expirationTask: Task<Void, Never>?
    @ObservationIgnored private var afterPurchase: (() -> Void)?

    init(
        defaults: UserDefaults? = nil,
        allowanceStorage: (any GameAllowanceStorage)? = nil,
        productLoader: (any StoreProductLoading)? = nil,
        preferences: MonetizationPreferences? = nil,
        notificationCenter: (any LocalNotificationCenter)? = nil,
        startStoreKitTasks: Bool = true,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        let inMemory = arguments.contains("-in-memory-store")
        let resolvedDefaults = defaults ?? (inMemory ? UserDefaults(suiteName: "PipCount.UI.\(UUID().uuidString)")! : .standard)
        let resolvedPreferences = preferences ?? MonetizationPreferences(defaults: resolvedDefaults, ephemeral: inMemory || !startStoreKitTasks)
        let resolvedAllowance = allowanceStorage ?? (inMemory ? InMemoryGameAllowanceStorage() : KeychainGameAllowanceStorage())
        self.defaults = resolvedDefaults
        self.preferences = resolvedPreferences
        self.allowanceStorage = resolvedAllowance
        self.productLoader = productLoader ?? LiveStoreProductLoader()
        self.isInMemoryStore = inMemory
        self.launchArguments = arguments
        self.notificationScheduler = NotificationScheduler(
            center: notificationCenter ?? (inMemory || !startStoreKitTasks ? SilentLocalNotificationCenter() : SystemLocalNotificationCenter()),
            preferences: resolvedPreferences
        )
        self.gamesStartedCount = GameAllowanceMigration.migrate(defaults: resolvedDefaults, storage: resolvedAllowance)
        self.entitlement = ProEntitlement(legacyUnlock: resolvedDefaults.bool(forKey: "proUnlocked"))
        applyLaunchArguments()
        if startStoreKitTasks && !inMemory {
            transactionUpdatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { return }
                    guard case .verified(let transaction) = result,
                          ProProduct(rawValue: transaction.productID) != nil else { continue }
                    await self?.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
        expirationTask?.cancel()
    }

    func prepareForLaunch(hasSavedGames: Bool) async {
        guard !hasPreparedLaunch else { return }
        preferences.establishAccessPolicy(usedStarts: gamesStartedCount, hasSavedGames: hasSavedGames)
        if !isInMemoryStore { await refreshEntitlements() }
        hasPreparedLaunch = true
        if isInMemoryStore && launchArguments.contains("-open-gift") && !isPro {
            presentPaywall(.gift)
        } else if !isPro && !isGrandfathered {
            presentPaywall()
        }
        await synchronizeServices()
    }

    func foreground() async {
        guard hasPreparedLaunch else { return }
        if !isInMemoryStore { await refreshEntitlements() }
        await synchronizeServices()
    }

    func loadProducts(forceRetry: Bool = false) async {
        guard productState != .loading else { return }
        if !forceRetry && productState == .loaded {
            productState = .loading
            trialEligibleProducts.removeAll()
            await refreshTrialEligibility()
            productState = .loaded
            return
        }
        productState = .loading
        var loaded: [ProProduct: Product] = [:]
        var lookupFailed = false
        for plan in ProProduct.allCases {
            do {
                if let product = try await productLoader.product(withID: plan.rawValue) {
                    loaded[plan] = product
                }
            } catch {
                lookupFailed = true
            }
        }
        products = loaded
        await refreshTrialEligibility()
        productState = loaded.isEmpty
            ? .unavailable(lookupFailed ? "Unable to load PipCount Pro right now" : "PipCount Pro is unavailable right now")
            : .loaded
    }

    func canPurchase(_ plan: ProProduct) -> Bool { productState == .loaded && products[plan] != nil && !isBusy }

    func trialPeriodText(for plan: ProProduct) -> String? {
        guard trialEligibleProducts.contains(plan), let offer = products[plan]?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: return nil
        }
        let count = period.value * offer.periodCount
        return "\(count) \(unit)\(count == 1 ? "" : "s")"
    }

    @discardableResult
    func purchase(_ plan: ProProduct) async -> Bool {
        guard !isBusy else { return false }
        guard canPurchase(plan), let product = products[plan] else {
            purchaseState = .failed("The purchase is not available right now")
            return false
        }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    purchaseState = .failed("Your purchase could not be verified")
                    return false
                }
                await refreshEntitlements()
                await transaction.finish()
                guard isPro else {
                    purchaseState = .failed("Your purchase could not be verified, so please try Restore")
                    return false
                }
                purchaseState = .success
                if entitlement.trialEnd != nil && !hasConverted {
                    await notificationScheduler.askPermissionIfNeeded(entitlement: entitlement)
                    await synchronizeServices()
                }
                paywallRoute = nil
                return true
            case .pending:
                purchaseState = .failed("Your purchase is waiting for approval")
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .failed("Your purchase could not be completed")
            }
        } catch {
            purchaseState = Self.purchaseState(for: error)
        }
        return false
    }

    @discardableResult
    func restore() async -> Bool {
        guard !isBusy else { return false }
        purchaseState = .restoring
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if isPro {
                purchaseState = .success
                paywallRoute = nil
                return true
            }
            purchaseState = .failed("We couldn’t find a PipCount Pro purchase for this account")
        } catch {
            purchaseState = .failed("Your purchases could not be restored right now")
        }
        return false
    }

    func refreshEntitlements() async {
        var snapshot = ProEntitlement(legacyUnlock: defaults.bool(forKey: "proUnlocked"))
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let plan = ProProduct(rawValue: transaction.productID),
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            if plan == .lifetime {
                snapshot.lifetime = true
            } else if let expiration = transaction.expirationDate {
                let status = await transaction.subscriptionStatus
                var state: ProEntitlement.Subscription.State = .active
                var validUntil = expiration
                if let status {
                    guard case .verified = status.transaction,
                          case .verified(let renewal) = status.renewalInfo else { continue }
                    switch status.state {
                    case .subscribed: state = .active
                    case .inGracePeriod:
                        state = .gracePeriod
                        validUntil = renewal.gracePeriodExpirationDate ?? expiration
                    case .revoked: state = .revoked
                    default: state = .expired
                    }
                }
                let freeTrial = transaction.offer?.type == .introductory && transaction.offer?.paymentMode == .freeTrial
                snapshot.subscriptions.append(.init(state: state, validUntil: validUntil, isFreeTrial: freeTrial, trialEnd: freeTrial ? expiration : nil))
            }
        }
        snapshot.evaluatedAt = Date()
        applyEntitlementSnapshot(snapshot)
        await synchronizeServices()
    }

    func applyEntitlementSnapshot(_ snapshot: ProEntitlement) {
        entitlement = snapshot
        if snapshot.hasConverted { preferences.set(.converted) }
        updateQuickAction()
        if snapshot.isPro {
            trialEligibleProducts.removeAll()
            paywallRoute = nil
        }
        expirationTask?.cancel()
        if !isInMemoryStore, let next = snapshot.subscriptions.filter({ $0.isActive(at: snapshot.evaluatedAt) }).map(\.validUntil).min() {
            expirationTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow))) }
                catch { return }
                await self?.refreshEntitlements()
            }
        }
    }

    func presentPaywall(_ route: PaywallRoute = .main, afterPurchase: (() -> Void)? = nil) {
        guard !isPro else { afterPurchase?(); return }
        self.afterPurchase = afterPurchase
        purchaseState = .idle
        paywallPresentedThisSession = true
        if route == .gift { preferences.set(.exitOfferSeen) }
        paywallRoute = route
    }

    func closePaywall() {
        guard let route = paywallRoute else { return }
        preferences.set(.paywallDismissed)
        updateQuickAction()
        if route == .main && !isPro && preferences.claimExitOffer() {
            purchaseState = .idle
            paywallRoute = .gift
        } else {
            paywallRoute = nil
            if route == .gift && !hasConverted {
                preferences.setDateOnce(.exitOfferClosedAt, date: Date())
                Task { [weak self] in
                    guard let self else { return }
                    if self.entitlement.trialEnd == nil {
                        await self.notificationScheduler.askPermissionIfNeeded(entitlement: self.entitlement)
                    }
                    await self.synchronizeServices()
                }
            }
        }
    }

    func dismissPaywallForNavigation() {
        afterPurchase = nil
        paywallRoute = nil
    }

    func paywallDidDismiss() {
        let action = isPro ? afterPurchase : nil
        afterPurchase = nil
        action?()
    }

    func recordGameStarted() {
        preferences.establishAccessPolicy(usedStarts: gamesStartedCount, hasSavedGames: false)
        let next = max(gamesStartedCount, allowanceStorage.readCount() ?? 0) + 1
        gamesStartedCount = next
        allowanceStorage.writeCount(next)
        defaults.set(next, forKey: "gamesStartedCount")
    }

    static func purchaseState(for error: Error) -> PurchaseState {
        if case StoreKitError.userCancelled = error { return .idle }
        return .failed("Your purchase could not be completed")
    }

    private func refreshTrialEligibility() async {
        var eligible: Set<ProProduct> = []
        for (plan, product) in products {
            if let subscription = product.subscription, await subscription.isEligibleForIntroOffer {
                eligible.insert(plan)
            }
        }
        trialEligibleProducts = eligible
    }

    private func synchronizeServices() async {
        updateQuickAction()
        await notificationScheduler.synchronize(entitlement: currentEntitlement)
    }

    private func updateQuickAction() {
        guard !isInMemoryStore else { return }
        AppEntryPoint.shared.updateQuickAction(isPro: isPro, hasDismissedPaywall: preferences.value(.paywallDismissed) > 0)
    }

    private func applyLaunchArguments() {
        guard isInMemoryStore else { return }
        if let index = launchArguments.firstIndex(of: "-grandfathered"), launchArguments.indices.contains(index + 1) {
            gamesStartedCount = max(0, Int(launchArguments[index + 1]) ?? 0)
            preferences.set(.accessPolicy, to: 2)
        }
        if launchArguments.contains("-free-games-exhausted") {
            gamesStartedCount = Self.freeGameLimit
            preferences.set(.accessPolicy, to: 2)
        }
        if launchArguments.contains("-fresh-install") {
            gamesStartedCount = 0
        }
        allowanceStorage.writeCount(gamesStartedCount)
        if launchArguments.contains("-exit-offer-seen") { preferences.set(.exitOfferSeen) }
        entitlement = ProEntitlement()
        if launchArguments.contains("-trial-active") {
            let end = Date().addingTimeInterval(3 * 24 * 60 * 60)
            entitlement.subscriptions = [.init(state: .active, validUntil: end, isFreeTrial: true, trialEnd: end)]
        }
        if launchArguments.contains("-unlock-pro") { entitlement.legacyUnlock = true }
    }
}
