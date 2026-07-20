import SwiftUI

struct RoundTracker: View {
    let totalRounds: Int
    let currentRound: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: 4) {
                Text("Round")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Text("\(currentRound)")
                    .font(AppFonts.caption.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.bauhausBlue)
                    .monospacedDigit()

                Text("of")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Text("\(max(totalRounds, currentRound))")
                    .font(AppFonts.caption.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .monospacedDigit()
            }

            BauhausRoundDots(
                current: currentRound,
                total: max(totalRounds, currentRound),
                activeColor: ClubhouseTheme.bauhausBlue
            )
        }
        .padding(.horizontal, AppTheme.spacingMedium)
    }
}
