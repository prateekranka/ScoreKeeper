import Foundation
import Security

/// Storage for the anonymous, this-device free-game allowance.
///
/// The protocol keeps StoreManager deterministic in tests and prevents UI tests
/// that use `-in-memory-store` from touching the host/device Keychain.
protocol GameAllowanceStorage: AnyObject {
    func readCount() -> Int?
    func writeCount(_ count: Int)
}

/// The production allowance store. Keychain items marked this-device-only
/// survive app deletion/reinstallation but are not restored to another device.
final class KeychainGameAllowanceStorage: GameAllowanceStorage {
    static let defaultAccount = "anonymous-free-game-count"

    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "com.icequeen.scorekeeper",
        account: String = KeychainGameAllowanceStorage.defaultAccount
    ) {
        self.service = service
        self.account = account
    }

    func readCount() -> Int? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let count = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return max(0, count)
    }

    func writeCount(_ count: Int) {
        let normalizedCount = max(max(0, count), readCount() ?? 0)
        let data = Data(String(normalizedCount).utf8)

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// Volatile storage used by unit tests and `-in-memory-store` UI-test launches.
final class InMemoryGameAllowanceStorage: GameAllowanceStorage {
    private(set) var count: Int?

    init(count: Int? = nil) {
        self.count = count
    }

    func readCount() -> Int? {
        count
    }

    func writeCount(_ count: Int) {
        self.count = max(max(0, count), self.count ?? 0)
    }
}

enum GameAllowanceMigration {
    /// Idempotently migrates the legacy UserDefaults count into Keychain.
    /// The larger non-negative value wins so a stale UserDefaults value can
    /// never reduce a count already retained by this device's Keychain.
    @discardableResult
    static func migrate(
        defaults: UserDefaults,
        storage: any GameAllowanceStorage,
        defaultsKey: String = "gamesStartedCount"
    ) -> Int {
        let keychainCount = max(0, storage.readCount() ?? 0)
        let legacyDefaultsCount = max(0, defaults.integer(forKey: defaultsKey))
        let migratedCount = max(keychainCount, legacyDefaultsCount)

        storage.writeCount(migratedCount)
        defaults.set(migratedCount, forKey: defaultsKey)
        return migratedCount
    }
}
