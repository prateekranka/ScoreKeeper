import Foundation

@MainActor
final class MonetizationPreferences {
    enum Key: String, CaseIterable {
        case accessPolicy, exitOfferSeen, paywallDismissed, converted, permissionAsked
        case exitOfferClosedAt, weeklyAnchor
    }

    private let defaults: UserDefaults
    private let storage: [Key: any GameAllowanceStorage]

    init(defaults: UserDefaults, ephemeral: Bool = false, storage: [Key: any GameAllowanceStorage]? = nil) {
        self.defaults = defaults
        self.storage = storage ?? Dictionary(uniqueKeysWithValues: Key.allCases.map { key in
            let value: any GameAllowanceStorage = ephemeral
                ? InMemoryGameAllowanceStorage()
                : KeychainGameAllowanceStorage(account: "monetization-\(key.rawValue)")
            return (key, value)
        })
    }

    func value(_ key: Key) -> Int {
        max(defaults.integer(forKey: "monetization.\(key.rawValue)"), storage[key]?.readCount() ?? 0)
    }

    func set(_ key: Key, to value: Int = 1) {
        let next = max(self.value(key), value)
        defaults.set(next, forKey: "monetization.\(key.rawValue)")
        storage[key]?.writeCount(next)
    }

    func setDateOnce(_ key: Key, date: Date) {
        guard value(key) == 0 else { return }
        set(key, to: Int(date.timeIntervalSince1970))
    }

    func date(_ key: Key) -> Date? {
        let seconds = value(key)
        return seconds > 0 ? Date(timeIntervalSince1970: Double(seconds)) : nil
    }

    func claimExitOffer() -> Bool {
        guard value(.exitOfferSeen) == 0 else { return false }
        set(.exitOfferSeen)
        return true
    }

    func establishAccessPolicy(usedStarts: Int, hasSavedGames: Bool) {
        guard value(.accessPolicy) == 0 else { return }
        set(.accessPolicy, to: usedStarts > 0 || hasSavedGames ? 2 : 1)
    }
}
