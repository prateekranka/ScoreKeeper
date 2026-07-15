import Foundation
import Observation

@MainActor
@Observable
final class ReviewAskManager {
    /// Signals that ContentView should invoke Apple's native review request.
    /// This is intentionally a transient state value; there is no custom review UI.
    var reviewRequestPending = false

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
        guard !reviewRequestPending else { return }

        if forceReviewAskPending || (shouldForceFromLaunchArguments && !didConsumeForceReviewAsk) {
            forceReviewAskPending = false
            didConsumeForceReviewAsk = true
            defaults.set(now, forKey: ReviewAskKeys.lastReviewAskDate)
            reviewRequestPending = true
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
        reviewRequestPending = true
    }

    /// Clears the transient signal after ContentView invokes the native request.
    /// The existing date throttle remains the source of truth for a future ask;
    /// native StoreKit review requests do not expose whether a user responded.
    func consumeReviewRequest() {
        guard reviewRequestPending else { return }
        reviewRequestPending = false
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
