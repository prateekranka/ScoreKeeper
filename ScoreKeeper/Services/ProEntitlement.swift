import Foundation

enum ProProduct: String, CaseIterable, Sendable {
    case yearly = "com.icequeen.scorekeeper.pro.yearly"
    case gift = "com.icequeen.scorekeeper.pro.yearly.gift"
    case lifetime = "com.icequeen.scorekeeper.unlimited"
}

enum PaywallRoute: String, Identifiable, Sendable {
    case main
    case gift

    var id: String { rawValue }
}

struct ProEntitlement: Equatable, Sendable {
    struct Subscription: Equatable, Sendable {
        enum State: Equatable, Sendable {
            case active, gracePeriod, expired, revoked
        }

        let state: State
        let validUntil: Date
        let isFreeTrial: Bool
        let trialEnd: Date?

        func isActive(at date: Date) -> Bool {
            (state == .active || state == .gracePeriod) && validUntil > date
        }
    }

    var lifetime = false
    var legacyUnlock = false
    var subscriptions: [Subscription] = []
    var evaluatedAt = Date()

    var isPro: Bool {
        lifetime || legacyUnlock || subscriptions.contains { $0.isActive(at: evaluatedAt) }
    }

    var hasConverted: Bool {
        lifetime || legacyUnlock || subscriptions.contains {
            $0.isActive(at: evaluatedAt) && !$0.isFreeTrial
        }
    }

    var trialEnd: Date? {
        guard !hasConverted else { return nil }
        return subscriptions.filter { $0.isActive(at: evaluatedAt) && $0.isFreeTrial }
            .compactMap(\.trialEnd).max()
    }
}

struct GameAccessPolicy: Equatable, Sendable {
    static let freeGameLimit = 25
    let isGrandfathered: Bool
    let gamesStartedCount: Int

    var remainingFreeGames: Int {
        isGrandfathered ? max(0, Self.freeGameLimit - max(0, gamesStartedCount)) : 0
    }

    func canStartNewGame(isPro: Bool) -> Bool {
        isPro || remainingFreeGames > 0
    }

    func showsRemainingCount(isPro: Bool) -> Bool {
        isGrandfathered && !isPro && remainingFreeGames <= 3
    }
}
