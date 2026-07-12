import StoreKit
import SwiftUI

struct ReviewAskView: View {
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    ReleaseSheetHeader(
                        title: "How was game night?",
                        subtitle: "A quick note from the person behind ScoreKeeper.",
                        systemImage: "flag.checkered"
                    )

                    notePanel
                }
                .padding(AppTheme.spacingMedium)
            }

            actionFooter
        }
        .appBackground()
    }

    private var notePanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ClubhouseTheme.felt)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Prateek")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)

                    Text("MAKER OF SCOREKEEPER")
                        .columnHeaderStyle()
                }
            }

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            Text("I built ScoreKeeper so score math wouldn't interrupt game night. If it helped your table, a quick rating helps other players find it too.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Either way, thanks for playing.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var actionFooter: some View {
        glassGroup(spacing: AppTheme.spacingSmall) {
            VStack(spacing: AppTheme.spacingSmall) {
                AppActionButton(role: .primary(ClubhouseTheme.felt)) {
                    reviewAskManager.acceptedReviewAsk()
                    dismiss()
                    requestReview()
                } label: {
                    Label("Rate ScoreKeeper", systemImage: "star.fill")
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
            .padding(AppTheme.spacingSmall)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.bottom, AppTheme.spacingSmall)
    }
}
