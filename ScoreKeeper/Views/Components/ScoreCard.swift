import SwiftUI

struct ScoreCard: View {
    let player: Player
    let totalScore: Int
    let isLeading: Bool

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .medium)

            Text("\(totalScore)")
                .font(AppFonts.scoreMedium)
                .monospacedDigit()
                .foregroundStyle(isLeading ? ClubhouseTheme.brass : ClubhouseTheme.ink)
                .contentTransition(.numericText(value: Double(totalScore)))

            if isLeading {
                BrassCrown()
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(minWidth: 100)
        .background(isLeading ? PlayerColors.lightColor(for: player.colorIndex) : Color.clear)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .strokeBorder(
                    isLeading ? ClubhouseTheme.brass : .clear,
                    lineWidth: 2
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(player.name), total score \(totalScore)\(isLeading ? ", leading" : "")")
    }
}
