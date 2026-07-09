import StoreKit
import SwiftUI

struct ReviewAskView: View {
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppTheme.spacingLarge) {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                Text("A note from the developer")
                    .columnHeaderStyle()

                Text("""
                Hi — I'm Prateek. I built ScoreKeeper because our game nights kept getting interrupted by score-math in the Notes app. It's just me building this, and a quick rating genuinely decides whether the app gets found. Either way, thanks for letting it keep score at your table.

                — Prateek
                """)
                .font(.system(.body, design: .serif))
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.spacingLarge)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)

            VStack(spacing: AppTheme.spacingSmall) {
                AppActionButton(role: .primary(ClubhouseTheme.felt)) {
                    reviewAskManager.acceptedReviewAsk()
                    dismiss()
                    requestReview()
                } label: {
                    Text("Sure, I'll rate it")
                }
                .accessibilityIdentifier("review_ask_rate_button")

                Button("Maybe later") {
                    reviewAskManager.declinedReviewAsk()
                    dismiss()
                }
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .frame(minHeight: 44)
                .accessibilityIdentifier("review_ask_later_button")
            }
        }
        .padding(AppTheme.spacingMedium)
        .appBackground()
    }
}
