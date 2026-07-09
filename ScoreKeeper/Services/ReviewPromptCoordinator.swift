import Foundation

@MainActor
@Observable
final class ReviewPromptCoordinator {
    static let successfulGamesBeforeRequest = 4

    private enum Keys {
        static let successfulGameCount = "reviewPrompt.successfulGameCount"
        static let lastPromptedVersion = "reviewPrompt.lastPromptedVersion"
    }

    private let defaults: UserDefaults
    private let isUITesting: Bool
    private let currentVersion: String

    private(set) var successfulGameCount: Int
    private(set) var lastPromptedVersion: String

    init(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    ) {
        self.defaults = defaults
        self.isUITesting = arguments.contains("-in-memory-store")
        self.currentVersion = currentVersion
        successfulGameCount = isUITesting ? 0 : defaults.integer(forKey: Keys.successfulGameCount)
        lastPromptedVersion = isUITesting ? "" : defaults.string(forKey: Keys.lastPromptedVersion) ?? ""
    }

    var shouldRequestReview: Bool {
        !isUITesting
            && successfulGameCount >= Self.successfulGamesBeforeRequest
            && !currentVersion.isEmpty
            && lastPromptedVersion != currentVersion
    }

    func recordSuccessfulGame() {
        successfulGameCount += 1
        guard !isUITesting else { return }
        defaults.set(successfulGameCount, forKey: Keys.successfulGameCount)
    }

    func reconcile(existingCompletedGameCount: Int) {
        guard !isUITesting, existingCompletedGameCount > successfulGameCount else { return }
        successfulGameCount = existingCompletedGameCount
        defaults.set(successfulGameCount, forKey: Keys.successfulGameCount)
    }

    func markRequestAttempted() {
        lastPromptedVersion = currentVersion
        guard !isUITesting else { return }
        defaults.set(currentVersion, forKey: Keys.lastPromptedVersion)
    }
}
