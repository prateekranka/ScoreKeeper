import Foundation
import Observation

@MainActor
@Observable
final class ReviewAskManager {
    var isPresentingReviewAsk = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let isFirstAppSession: Bool
    @ObservationIgnored private var forceReviewAskPending: Bool
    @ObservationIgnored private var didConsumeForceReviewAsk = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-in-memory-store")
        let shouldForceReviewAsk = isUITesting && arguments.contains("-force-review-ask")

        if isUITesting && !shouldForceReviewAsk {
            defaults.removeObject(forKey: ReviewAskKeys.lastReviewAskDate)
            defaults.removeObject(forKey: ReviewAskKeys.didAcceptReviewAsk)
            defaults.removeObject(forKey: ReviewAskKeys.hasLaunchedBefore)
        }

        self.forceReviewAskPending = shouldForceReviewAsk
        self.isFirstAppSession = !defaults.bool(forKey: ReviewAskKeys.hasLaunchedBefore)
        defaults.set(true, forKey: ReviewAskKeys.hasLaunchedBefore)
    }

    func considerReviewAsk(completedGameCount: Int, paywallPresentedThisSession: Bool, now: Date = .now) {
        guard !isPresentingReviewAsk else { return }

        if forceReviewAskPending || (shouldForceFromLaunchArguments && !didConsumeForceReviewAsk) {
            forceReviewAskPending = false
            didConsumeForceReviewAsk = true
            isPresentingReviewAsk = true
            return
        }

        guard (completedGameCount == 2 || completedGameCount == 5),
              !isFirstAppSession,
              !paywallPresentedThisSession,
              !defaults.bool(forKey: ReviewAskKeys.didAcceptReviewAsk) else {
            return
        }

        if let lastAsk = defaults.object(forKey: ReviewAskKeys.lastReviewAskDate) as? Date,
           now.timeIntervalSince(lastAsk) < 120 * 24 * 60 * 60 {
            return
        }

        defaults.set(now, forKey: ReviewAskKeys.lastReviewAskDate)
        isPresentingReviewAsk = true
    }

    func acceptedReviewAsk() {
        defaults.set(true, forKey: ReviewAskKeys.didAcceptReviewAsk)
        isPresentingReviewAsk = false
    }

    func declinedReviewAsk() {
        isPresentingReviewAsk = false
    }

    private var shouldForceFromLaunchArguments: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-in-memory-store") && arguments.contains("-force-review-ask")
    }
}

private enum ReviewAskKeys {
    static let hasLaunchedBefore = "reviewAskHasLaunchedBefore"
    static let lastReviewAskDate = "lastReviewAskDate"
    static let didAcceptReviewAsk = "didAcceptReviewAsk"
}
